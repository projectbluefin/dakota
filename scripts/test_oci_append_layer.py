"""Thin boot-layer OCI assembly tests; fixtures need no container/network."""
from __future__ import annotations

import hashlib
import io
import json
import os
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

from scripts import oci_append_layer as append
from scripts import ownership_metadata as metadata
from scripts.test_ownership_oci import entry
from scripts.test_ownership_overlay import BASE_OWNER, BOOT_OWNER, base_layer, boot_layer, structure

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = "application/vnd.oci.image.manifest.v1+json"
CONFIG = "application/vnd.oci.image.config.v1+json"


def tar_bytes(entries):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w", format=tarfile.PAX_FORMAT) as archive:
        for member, data in entries:
            archive.addfile(member, io.BytesIO(data) if member.isfile() else None)
    return stream.getvalue()


def base_layout(root, layers):
    """A build-oci shaped layout: real config, platform and bootc annotation."""
    blobs = root / "blobs/sha256"
    blobs.mkdir(parents=True)

    def blob(data, media_type):
        digest = hashlib.sha256(data).hexdigest()
        (blobs / digest).write_bytes(data)
        return {"mediaType": media_type, "digest": "sha256:" + digest, "size": len(data)}

    tars = [tar_bytes(entries) for entries in layers]
    config = {"created": "2011-11-11T11:11:11Z", "architecture": "amd64", "os": "linux",
              "config": {"Labels": {"containers.bootc": "1"}},
              "rootfs": {"type": "layers", "diff_ids": ["sha256:" + hashlib.sha256(t).hexdigest() for t in tars]},
              "history": [{"comment": "Import Bluefin layer"}]}
    manifest = {"schemaVersion": 2, "layers": [blob(t, append.LAYER_MEDIA_TYPE) for t in tars],
                "config": blob(json.dumps(config).encode(), CONFIG)}
    descriptor = blob(json.dumps(manifest).encode(), MANIFEST)
    descriptor["platform"] = {"os": "linux", "architecture": "amd64"}
    descriptor["annotations"] = {"org.opencontainers.image.ref.name": "ghcr.io/projectbluefin/dakota:latest"}
    (root / "index.json").write_text(json.dumps({"schemaVersion": 2, "manifests": [descriptor]}))
    (root / "oci-layout").write_text('{"imageLayoutVersion":"1.0.0"}')
    return root


def read(layout, descriptor):
    return json.loads((layout / "blobs/sha256" / descriptor["digest"].split(":")[1]).read_bytes())


class AppendLayerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.tmp = Path(self.temporary.name)
        self.base = base_layout(self.tmp / "base", [base_layer()])
        self.layer = self.tmp / "boot.tar"
        self.layer.write_bytes(tar_bytes(boot_layer()))
        self.output = self.tmp / "final"

    def tearDown(self):
        self.temporary.cleanup()

    def test_appends_only_the_layer_diff_id_and_history(self):
        descriptor = append.append_layer(self.base, self.layer, self.output, "Boot layer")
        base_index = json.loads((self.base / "index.json").read_text())
        base_entry = base_index["manifests"][0]
        base_manifest = read(self.base, base_entry)
        base_config = read(self.base, base_manifest["config"])
        manifest = read(self.output, descriptor)
        config = read(self.output, manifest["config"])
        digest = "sha256:" + hashlib.sha256(self.layer.read_bytes()).hexdigest()

        self.assertEqual(manifest["layers"][:-1], base_manifest["layers"])
        self.assertEqual(manifest["layers"][-1]["digest"], digest)
        self.assertEqual({k: v for k, v in manifest.items() if k not in ("layers", "config")},
                         {k: v for k, v in base_manifest.items() if k not in ("layers", "config")})
        self.assertEqual(config["rootfs"]["diff_ids"], base_config["rootfs"]["diff_ids"] + [digest])
        self.assertEqual(config["history"], base_config["history"] + [{"comment": "Boot layer"}])
        self.assertEqual({k: v for k, v in config.items() if k not in ("rootfs", "history")},
                         {k: v for k, v in base_config.items() if k not in ("rootfs", "history")})
        self.assertEqual(descriptor["platform"], base_entry["platform"])
        self.assertEqual(descriptor["annotations"], base_entry["annotations"])
        index = json.loads((self.output / "index.json").read_text())
        self.assertEqual(index["manifests"], [descriptor])
        for layer in manifest["layers"]:
            blob = self.output / "blobs/sha256" / layer["digest"].split(":")[1]
            self.assertEqual(hashlib.sha256(blob.read_bytes()).hexdigest(), layer["digest"].split(":")[1])

    def test_result_passes_the_overlay_ownership_merge(self):
        tree, digest = metadata.oci_snapshot(self.base)
        owners = {path: BASE_OWNER for path, record in tree.items() if record["type"] != "directory"}
        sidecar = self.tmp / "base.json"
        metadata._write_json(sidecar, metadata._final_payload(tree, owners, "fixture", "0" * 64,
                                                              "amd64", "default", digest))
        basis = self.tmp / "boot-basis.json"
        kinds = structure(boot_layer())
        basis.write_text(json.dumps({"schema": 3, "layer_artifact": "fixture", "structure": kinds, "entries": [
            {"path": "/" + p, **BOOT_OWNER} for p, k in kinds.items() if k != "directory"]}))
        append.append_layer(self.base, self.layer, self.output, "Boot layer")
        final = self.tmp / "final.json"
        metadata.finalize_overlay(self.output, self.base, sidecar, basis, ["/usr/lib/modules"],
                                  "amd64", "default", final, ["/usr/bin/tool"])
        self.assertEqual(metadata._load_final(final)["oci_manifest_digest"],
                         metadata._manifest_from_layout(self.output)[1])

    def test_rejects_multi_image_index(self):
        index = json.loads((self.base / "index.json").read_text())
        index["manifests"] *= 2
        (self.base / "index.json").write_text(json.dumps(index))
        with self.assertRaisesRegex(ValueError, "exactly one image manifest"):
            append.append_layer(self.base, self.layer, self.output, "Boot layer")

    def test_rejects_corrupt_base_layer(self):
        manifest = read(self.base, json.loads((self.base / "index.json").read_text())["manifests"][0])
        blob = self.base / "blobs/sha256" / manifest["layers"][0]["digest"].split(":")[1]
        blob.write_bytes(blob.read_bytes() + b"\0")
        with self.assertRaisesRegex(ValueError, "does not match its digest"):
            append.append_layer(self.base, self.layer, self.output, "Boot layer")

    def test_rejects_compressed_base_layers(self):
        index = json.loads((self.base / "index.json").read_text())
        manifest = read(self.base, index["manifests"][0])
        manifest["layers"][0]["mediaType"] += "+gzip"
        data = json.dumps(manifest).encode()
        digest = hashlib.sha256(data).hexdigest()
        (self.base / "blobs/sha256" / digest).write_bytes(data)
        index["manifests"][0]["digest"] = "sha256:" + digest
        (self.base / "index.json").write_text(json.dumps(index))
        with self.assertRaisesRegex(ValueError, "uncompressed"):
            append.append_layer(self.base, self.layer, self.output, "Boot layer")


def _staged_oci_builder():
    for candidate in sorted((ROOT / ".bst/staged-junctions/freedesktop-sdk.bst").glob("*/files/oci")):
        if (candidate / "oci_builder/layer_builder.py").is_file():
            return candidate
    return None


@unittest.skipUnless(_staged_oci_builder(), "freedesktop-sdk junction is not staged")
class RealLayerWriterTests(unittest.TestCase):
    """Run the layer writer the sandbox uses when the junction is staged locally."""

    def test_layer_has_no_whiteouts_and_keeps_every_file(self):
        # The staged junction is a BuildStream local source: bytecode written
        # into it would change oci-builder's cache key.
        sys.dont_write_bytecode = True
        sys.path.insert(0, str(_staged_oci_builder()))
        with tempfile.TemporaryDirectory() as temporary:
            tmp = Path(temporary)
            upper = tmp / "upper/usr/lib/modules/6.1"
            upper.mkdir(parents=True)
            (upper / "vmlinuz").write_bytes(b"kernel")
            os.symlink("vmlinuz", upper / "link")
            layer = tmp / "layer.tar"
            append.build_layer_tar(tmp / "upper", layer)
            with tarfile.open(layer) as archive:
                names = [member.name for member in archive]
            self.assertFalse([name for name in names if ".wh." in name])
            self.assertIn("usr/lib/modules/6.1/vmlinuz", names)
            self.assertIn("usr/lib/modules/6.1/link", names)


if __name__ == "__main__":
    unittest.main()
