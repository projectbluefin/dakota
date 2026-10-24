"""Thin boot-layer ownership merge tests; fixtures need no container/network."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

from scripts import ownership_metadata as metadata
from scripts.test_ownership_oci import entry, layout_at

ROOT = Path(__file__).resolve().parents[1]
BASE_OWNER = {"component": "bluefin/tool.bst", "producer": "bluefin:bluefin/tool.bst", "interval": "weekly"}
BOOT_OWNER = {"component": "bluefin/boot.bst", "producer": "bluefin:bluefin/boot.bst", "interval": "monthly"}
PREFIX = ["/usr/lib/modules"]


def base_layer():
    return [entry("usr", "directory"), entry("usr/bin", "directory"), entry("usr/bin/tool"),
            entry("usr/bin/link", "symlink", target="tool", mode=0o777), entry("usr/lib", "directory"),
            entry("usr/lib/os-release", data=b"VERSION_ID=0\nNAME=Dakota\n")]


def boot_layer():
    return [entry("usr", "directory"), entry("usr/lib", "directory"),
            entry("usr/lib/modules", "directory"), entry("usr/lib/modules/6.1", "directory"),
            entry("usr/lib/modules/6.1/vmlinuz", data=b"kernel"),
            entry("usr/lib/modules/6.1/modules.dep", data=b"dep")]


def structure(entries):
    kinds = {tarfile.DIRTYPE: "directory", tarfile.SYMTYPE: "symlink"}
    return {member.name: kinds.get(member.type, "file") for member, _ in entries}


class FinalizeOverlayTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.tmp = Path(self.temporary.name)
        self.base_layout = layout_at(self.tmp / "base", [base_layer()])
        tree, digest = metadata.oci_snapshot(self.base_layout)
        owners = {path: BASE_OWNER for path, record in tree.items() if record["type"] in ("file", "symlink")}
        payload = metadata._final_payload(tree, owners, "bluefin/oci-bluefin/fixture",
                                          "0" * 64, "amd64", "default", digest)
        payload["os_release_lines"] = ["VERSION_ID=0\n", "NAME=Dakota\n"]
        self.base_sidecar = self.tmp / "base.json"
        metadata._write_json(self.base_sidecar, payload)
        self.output = self.tmp / "final.json"

    def tearDown(self):
        self.temporary.cleanup()

    def basis(self, entries, name="boot-basis.json"):
        kinds = structure(entries)
        path = self.tmp / name
        path.write_text(json.dumps({
            "schema": 3, "layer_artifact": "bluefin/oci-layers-boot/fixture", "structure": kinds,
            "entries": [{"path": "/" + p, **BOOT_OWNER} for p, k in kinds.items() if k != "directory"],
        }))
        return path

    def run_merge(self, overlay=None, basis_entries=None, base=None, prefixes=PREFIX,
                  base_layout=None, variant="default"):
        overlay = boot_layer() if overlay is None else overlay
        layout = layout_at(self.tmp / "image", [base or base_layer(), overlay])
        basis = self.basis(overlay if basis_entries is None else basis_entries)
        metadata.finalize_overlay(layout, base_layout or self.base_layout, self.base_sidecar,
                                  basis, prefixes, "amd64", variant, self.output)
        return layout

    def test_merge_keeps_base_owners_and_claims_boot_paths(self):
        layout = self.run_merge()
        final = metadata._load_final(self.output)
        owners = {item["path"]: item["component"] for item in final["entries"]}
        self.assertEqual(owners["/usr/bin/tool"], BASE_OWNER["component"])
        self.assertEqual(owners["/usr/bin/link"], BASE_OWNER["component"])
        self.assertEqual(owners["/usr/lib/modules/6.1/vmlinuz"], BOOT_OWNER["component"])
        self.assertEqual(final["snapshot"], metadata.oci_snapshot(layout)[0])
        self.assertEqual(final["oci_manifest_digest"], metadata.oci_snapshot(layout)[1])
        self.assertEqual(final["binding"], "oci-layout")
        self.assertEqual(final["os_release_lines"], ["VERSION_ID=0\n", "NAME=Dakota\n"])
        self.assertEqual(final["overlay"]["allow_prefixes"], PREFIX)

    def test_merged_sidecar_validates_the_extracted_image(self):
        layout = self.run_merge()
        manifest, _ = metadata._manifest_from_layout(layout)
        root = self.tmp / "root"
        root.mkdir()
        for layer in manifest["layers"]:
            with tarfile.open(layout / "blobs/sha256" / layer["digest"].split(":")[1]) as archive:
                archive.extractall(root, filter="data")
                # tarfile cannot restore symlink mtimes; Podman's export does.
                for member in archive:
                    if member.issym():
                        os.utime(root / member.name, ns=(member.mtime * 10**9,) * 2, follow_symlinks=False)
        manifest_tsv = self.tmp / "manifest.tsv"
        metadata.validate_exported(root, self.output, "amd64", "default", manifest_tsv)
        self.assertIn("/usr/lib/modules/6.1/vmlinuz\tbluefin/boot.bst\tmonthly\n", manifest_tsv.read_text())

    def test_rejects_overlay_path_outside_prefixes(self):
        overlay = boot_layer() + [entry("usr/bin", "directory"), entry("usr/bin/tool", data=b"evil")]
        with self.assertRaisesRegex(ValueError, "outside the allowed prefixes"):
            self.run_merge(overlay)

    def test_rejects_os_release_even_when_prefix_allows_it(self):
        overlay = boot_layer() + [entry("usr/lib/os-release", data=b"VERSION_ID=9\n")]
        with self.assertRaisesRegex(ValueError, "os-release"):
            self.run_merge(overlay, prefixes=["/usr/lib"])

    def test_rejects_whiteouts(self):
        overlay = boot_layer() + [entry("usr/lib/modules/.wh.old", data=b"")]
        with self.assertRaisesRegex(ValueError, "additive"):
            self.run_merge(overlay)

    def test_rejects_changed_ancestor_directory_metadata(self):
        overlay = boot_layer()
        overlay[0] = entry("usr", "directory", mode=0o700)
        with self.assertRaisesRegex(ValueError, "ancestor directory"):
            self.run_merge(overlay)

    def test_rejects_modified_base_layers(self):
        changed = base_layer()[:-1] + [entry("usr/lib/os-release", data=b"VERSION_ID=1\n")]
        with self.assertRaisesRegex(ValueError, "exact base layers"):
            self.run_merge(base=changed)

    def test_rejects_sidecar_from_another_base(self):
        other = layout_at(self.tmp / "other", [base_layer() + [entry("usr/bin/extra")]])
        with self.assertRaisesRegex(ValueError, "not bound to the staged base"):
            self.run_merge(base_layout=other)

    def test_rejects_overlay_that_differs_from_its_basis(self):
        with self.assertRaisesRegex(ValueError, "does not match its basis"):
            self.run_merge(basis_entries=boot_layer()[:-1])

    def test_rejects_variant_mismatch(self):
        with self.assertRaisesRegex(ValueError, "variant"):
            self.run_merge(variant="nvidia")

    def test_rejects_hardlink_into_base_content(self):
        overlay = boot_layer() + [entry("usr/lib/modules/6.1/alias", "link", target="usr/bin/tool")]
        with self.assertRaises(ValueError):
            self.run_merge(overlay)

    def test_cli_requires_and_accepts_prefixes(self):
        layout = layout_at(self.tmp / "image", [base_layer(), boot_layer()])
        command = [sys.executable, ROOT / "scripts/ownership_metadata.py", "finalize-overlay",
                   "--layout", layout, "--base-layout", self.base_layout,
                   "--base-sidecar", self.base_sidecar, "--overlay-basis", self.basis(boot_layer()),
                   "--arch", "amd64", "--variant", "default", "--output", self.output]
        missing = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertNotEqual(missing.returncode, 0)
        result = subprocess.run(command + ["--allow-prefix", PREFIX[0]], capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        metadata._load_final(self.output)


if __name__ == "__main__":
    unittest.main()
