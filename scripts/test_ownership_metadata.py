#!/usr/bin/env python3
"""Offline safety tests for ownership sidecar metadata."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("ownership_metadata", ROOT / "scripts/ownership_metadata.py")
assert SPEC and SPEC.loader
metadata = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(metadata)


def finalize_fixture(root, basis_path, arch, variant, output):
    """Construct an exact snapshot for unit tests without a production CLI mode."""
    owners, _, layer_artifact, basis_digest = metadata._load_basis(basis_path)
    payload = metadata._final_payload(metadata.snapshot(root), owners, layer_artifact,
                                      basis_digest, arch, variant, "sha256:" + "0" * 64)
    metadata._write_json(output, payload)


class OwnershipMetadataTests(unittest.TestCase):
    def make_root(self, directory: Path) -> Path:
        root = directory / "root"
        (root / "usr/lib").mkdir(parents=True)
        (root / "usr/bin").mkdir()
        (root / "usr/lib/os-release").write_text("VERSION_ID=0\nIMAGE_VERSION=0\nNAME=Dakota\n")
        executable = root / "usr/bin/tool"
        executable.write_text("tool\n")
        executable.chmod(0o755)
        os.symlink("tool", root / "usr/bin/link")
        os.link(executable, root / "usr/bin/tool-alias")
        return root

    def basis(self, root: Path, destination: Path) -> Path:
        structure = metadata._structure(root)
        entries = []
        for path, file_type in structure.items():
            if file_type in ("file", "symlink"):
                entries.append({
                    "path": "/" + path,
                    "component": "bluefin/tool.bst",
                    "producer": "bluefin:bluefin/tool.bst",
                    "interval": "weekly",
                })
        destination.write_text(json.dumps({
            "schema": 3,
            "layer_artifact": "bluefin/oci-layers-bluefin/fixture",
            "structure": structure,
            "entries": entries,
        }))
        return destination

    def test_finalize_and_exact_export(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp = Path(temporary)
            root = self.make_root(tmp)
            basis = self.basis(root, tmp / "basis.json")
            sidecar = tmp / "sidecar.json"
            metadata.verify_basis(root, basis)
            finalize_fixture(root, basis, "x86_64", "default", sidecar)
            manifest = tmp / "manifest.tsv"
            metadata.validate_exported(root, sidecar, "x86_64", "default", manifest)
            release = root / "usr/lib/os-release"
            release_mtime = os.stat(release).st_mtime_ns
            release.write_text("VERSION_ID=20260101\nIMAGE_VERSION=20260101\nNAME=Dakota\n")
            os.utime(release, ns=(release_mtime, release_mtime))
            with self.assertRaisesRegex(ValueError, "unexplained changes"):
                metadata.validate_exported(root, sidecar, "x86_64", "default", manifest)
            release.write_text("VERSION_ID=0\nIMAGE_VERSION=0\nNAME=Dakota\n")
            os.utime(release, ns=(release_mtime, release_mtime))
            metadata.validate_exported(root, sidecar, "x86_64", "default", manifest)
            self.assertIn("/usr/bin/tool\tbluefin/tool.bst\tweekly", manifest.read_text())

    def test_oci_finalization_and_immutable_image_rebinding(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp = Path(temporary)
            root = self.make_root(tmp)
            basis = self.basis(root, tmp / "basis.json")
            layout = tmp / "layout"
            blobs = layout / "blobs/sha256"
            blobs.mkdir(parents=True)
            layer = tmp / "layer.tar"
            with tarfile.open(layer, "w", format=tarfile.GNU_FORMAT) as archive:
                for child in sorted(root.iterdir()):
                    archive.add(child, arcname=child.name, recursive=True)
            layer_digest = hashlib.sha256(layer.read_bytes()).hexdigest()
            (blobs / layer_digest).write_bytes(layer.read_bytes())
            config = b"{}"
            config_digest = hashlib.sha256(config).hexdigest()
            (blobs / config_digest).write_bytes(config)
            manifest_data = {
                "schemaVersion": 2,
                "config": {"mediaType": "application/vnd.oci.image.config.v1+json", "digest": "sha256:" + config_digest, "size": len(config)},
                "layers": [{"mediaType": "application/vnd.oci.image.layer.v1.tar", "digest": "sha256:" + layer_digest, "size": layer.stat().st_size}],
            }
            manifest_bytes = json.dumps(manifest_data, separators=(",", ":")).encode()
            manifest_digest = hashlib.sha256(manifest_bytes).hexdigest()
            (blobs / manifest_digest).write_bytes(manifest_bytes)
            (layout / "index.json").write_text(json.dumps({
                "schemaVersion": 2,
                "manifests": [{"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:" + manifest_digest, "size": len(manifest_bytes)}],
            }))
            (layout / "oci-layout").write_text('{"imageLayoutVersion":"1.0.0"}')

            source_sidecar = tmp / "source.json"
            metadata.finalize_oci(layout, root, basis, "amd64", "default", source_sidecar)
            source = json.loads(source_sidecar.read_text())
            self.assertEqual(source["binding"], "oci-layout")
            self.assertEqual(source["oci_manifest_digest"], "sha256:" + manifest_digest)

            exported = tmp / "exported"
            exported.mkdir()
            with tarfile.open(layer) as archive:
                archive.extractall(exported, filter="data")
            link_mtime = source["snapshot"]["usr/bin/link"]["mtime_ns"]
            os.utime(exported / "usr/bin/link", ns=(link_mtime, link_mtime), follow_symlinks=False)
            release = exported / "usr/lib/os-release"
            release_mtime = os.stat(release).st_mtime_ns
            release.write_text("VERSION_ID=20260101\nIMAGE_VERSION=20260101\nNAME=Dakota\n")
            os.utime(release, ns=(release_mtime, release_mtime))
            rebound = tmp / "rebound.json"
            manifest_tsv = tmp / "manifest.tsv"
            actual_release = metadata.snapshot(exported)["usr/lib/os-release"]
            self.assertTrue(metadata._os_release_change(
                source["snapshot"]["usr/lib/os-release"], actual_release
            ), (source["snapshot"]["usr/lib/os-release"], actual_release))
            image_id = "a" * 64
            actual_tree = metadata.snapshot(exported)
            differences = {
                path: (source["snapshot"].get(path), actual_tree.get(path))
                for path in sorted(set(source["snapshot"]) | set(actual_tree))
                if source["snapshot"].get(path) != actual_tree.get(path)
            }
            self.assertEqual(set(differences), {"usr/lib/os-release"}, differences)
            metadata.rebind_exported(exported, source_sidecar, image_id, "amd64", "default", rebound, manifest_tsv)
            final = json.loads(rebound.read_text())
            self.assertEqual(final["binding"], "final-image")
            self.assertEqual(final["image_id"], image_id)
            metadata.validate_exported(exported, rebound, "amd64", "default", manifest_tsv)
            (exported / "usr/bin/tool").write_text("tampered")
            with self.assertRaisesRegex(ValueError, "unexplained changes"):
                metadata.validate_exported(exported, rebound, None, None, None)

    def test_chunkify_rejects_tsv_corruption_and_freezes_validated_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp = Path(temporary)
            root = self.make_root(tmp)
            sidecar, manifest, frozen = tmp / "final.json", tmp / "manifest.tsv", tmp / "frozen.tsv"
            finalize_fixture(root, self.basis(root, tmp / "basis.json"), "amd64", "default", sidecar)
            state = json.loads(sidecar.read_text())
            state.update(binding="final-image", image_id="a" * 64)
            sidecar.write_text(json.dumps(state))
            metadata.validate_exported(root, sidecar, None, None, manifest)
            original = manifest.read_bytes()
            for data in (b"", original[:40], original.replace(b"weekly", b"monthly")):
                manifest.write_bytes(data)
                with self.assertRaisesRegex(ValueError, "TSV does not match"):
                    metadata.prepare_chunkify_manifest(sidecar, "a" * 64, manifest, frozen)
                self.assertFalse(frozen.exists())
            manifest.write_bytes(original)
            with self.assertRaisesRegex(ValueError, "not bound"):
                metadata.prepare_chunkify_manifest(sidecar, "b" * 64, manifest, frozen)
            metadata.prepare_chunkify_manifest(sidecar, "a" * 64, manifest, frozen)
            manifest.write_bytes(b"changed after validation")
            self.assertEqual(frozen.read_bytes(), original)

    def test_no_fixture_only_cli_command(self):
        result = subprocess.run([sys.executable, ROOT / "scripts/ownership_metadata.py", "finalize"],
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid choice", result.stderr)

    def test_rejects_mismatch_variant_drift_and_hardlink_conflict(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp = Path(temporary)
            root = self.make_root(tmp)
            basis = self.basis(root, tmp / "basis.json")
            sidecar = tmp / "sidecar.json"
            finalize_fixture(root, basis, "x86_64", "nvidia", sidecar)
            with self.assertRaisesRegex(ValueError, "variant"):
                metadata.validate_exported(root, sidecar, None, "default", None)
            final = json.loads(sidecar.read_text())
            for entry in final["entries"]:
                if entry["path"] == "/usr/bin/tool-alias":
                    entry["component"] = "other.bst"
            sidecar.write_text(json.dumps(final))
            with self.assertRaisesRegex(ValueError, "conflicting hardlink"):
                metadata.validate_exported(root, sidecar, None, None, None)
            (root / "usr/bin/unexpected").write_text("drift")
            with self.assertRaisesRegex(ValueError, "unexplained changes"):
                metadata.validate_exported(root, sidecar, None, None, None)

    def test_symlink_is_not_followed_and_basis_checks_structure_not_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp = Path(temporary)
            root = self.make_root(tmp)
            outside = tmp / "outside"
            outside.write_text("outside")
            os.symlink(outside, root / "usr/bin/outside")
            tree = metadata.snapshot(root)
            self.assertEqual(tree["usr/bin/outside"]["type"], "symlink")
            self.assertNotIn("outside", tree)
            basis = self.basis(root, tmp / "basis.json")

            # Ownership remains valid if a cache-equivalent artifact realization
            # differs only in bytes; finalization binds those exact bytes later.
            (root / "usr/bin/tool").write_text("different realization")
            metadata.verify_basis(root, basis)
            (root / "usr/bin/tool").unlink()
            (root / "usr/bin/tool").mkdir()
            with self.assertRaisesRegex(ValueError, "structure"):
                metadata.verify_basis(root, basis)

    def test_snapshot_records_xattrs_and_export_rejects_xattr_drift(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp = Path(temporary)
            root = self.make_root(tmp)
            tool = root / "usr/bin/tool"
            try:
                os.setxattr(tool, "user.dakota-test", b"one")
            except OSError as error:
                self.skipTest(f"test filesystem does not support user xattrs: {error}")
            basis = self.basis(root, tmp / "basis.json")
            sidecar = tmp / "sidecar.json"
            finalize_fixture(root, basis, "x86_64", "default", sidecar)
            final = json.loads(sidecar.read_text())
            self.assertIn("user.dakota-test", final["snapshot"]["usr/bin/tool"]["xattrs"])
            os.setxattr(tool, "user.dakota-test", b"two")
            with self.assertRaisesRegex(ValueError, "unexplained changes"):
                metadata.validate_exported(root, sidecar, None, None, None)


if __name__ == "__main__":
    unittest.main()
