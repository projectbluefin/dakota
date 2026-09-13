"""OCI layer semantics regression tests; fixtures need no container/network."""
from __future__ import annotations

import hashlib
import io
import json
import os
import stat
import tarfile
import tempfile
import unittest
from pathlib import Path

from scripts import ownership_metadata as metadata
from scripts.test_ownership_metadata import finalize_fixture


def entry(path, kind="file", data=b"data", target="", **attributes):
    member = tarfile.TarInfo(path)
    member.uid, member.gid = os.getuid(), os.getgid()
    member.mtime = 1321009871
    member.mode = 0o755 if kind == "directory" else 0o644
    member.type = {"file": tarfile.REGTYPE, "directory": tarfile.DIRTYPE,
                   "link": tarfile.LNKTYPE, "symlink": tarfile.SYMTYPE,
                   "char": tarfile.CHRTYPE, "block": tarfile.BLKTYPE}[kind]
    member.linkname = target
    member.size = len(data) if kind == "file" else 0
    for name, value in attributes.items():
        setattr(member, name, value)
    return member, data


def layout_at(root, layers):
    blobs = root / "blobs/sha256"
    blobs.mkdir(parents=True)

    def blob(data, media_type):
        digest = hashlib.sha256(data).hexdigest()
        (blobs / digest).write_bytes(data)
        return {"digest": "sha256:" + digest, "size": len(data), "mediaType": media_type}

    descriptors = []
    for entries in layers:
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode="w", format=tarfile.PAX_FORMAT) as archive:
            for member, data in entries:
                archive.addfile(member, io.BytesIO(data) if member.isfile() else None)
        descriptors.append(blob(stream.getvalue(), "application/vnd.oci.image.layer.v1.tar"))
    manifest = {"schemaVersion": 2, "layers": descriptors,
                "config": blob(b"{}", "application/vnd.oci.image.config.v1+json")}
    descriptor = blob(json.dumps(manifest).encode(), "application/vnd.oci.image.manifest.v1+json")
    (root / "index.json").write_text(json.dumps({"schemaVersion": 2, "manifests": [descriptor]}))
    (root / "oci-layout").write_text('{"imageLayoutVersion":"1.0.0"}')
    return root


class OCISnapshotTests(unittest.TestCase):
    def parse(self, *layers):
        with tempfile.TemporaryDirectory() as directory:
            return metadata.oci_snapshot(layout_at(Path(directory), layers))[0]

    def test_whiteouts_only_affect_lower_entries_in_any_order(self):
        lower = [entry("d", "directory"), entry("d/old"), entry("d/sub", "directory"),
                 entry("d/sub/old"), entry("keep")]
        for marker in ("d/.wh.old", "d/.wh..wh..opq", ".wh..wh..opq", ".wh.d"):
            whiteout = entry(marker, data=b"")
            new = [entry("d", "directory"), entry("d/old", data=b"new"), entry("fresh")]
            with self.subTest(marker=marker):
                early = self.parse(lower, [whiteout] + new)
                late = self.parse(lower, new + [whiteout])
                self.assertEqual(early, late)
                self.assertEqual(late["d/old"]["sha256"], hashlib.sha256(b"new").hexdigest())
                self.assertIn("fresh", late)
                self.assertFalse(any(".wh." in path for path in late))
                if marker != "d/.wh.old":
                    self.assertNotIn("d/sub", late)
                    self.assertNotIn("d/sub/old", late)
                if marker == ".wh..wh..opq":
                    self.assertNotIn("keep", late)

    def test_directory_metadata_overlay_keeps_lower_children(self):
        result = self.parse([entry("d", "directory"), entry("d/child")],
                            [entry("d", "directory", mode=0o700)])
        self.assertIn("d/child", result)
        self.assertEqual(result["d"]["mode"], 0o700)

    def test_directory_replaced_by_leaf_removes_descendants(self):
        result = self.parse([entry("d", "directory"), entry("d/child")],
                            [entry("d", data=b"new")])
        self.assertEqual(set(result), {"d"})
        self.assertEqual(result["d"]["type"], "file")

    def test_reject_invalid_whiteouts_duplicate_entries_and_paths(self):
        for entries in ([entry(".wh.", data=b"")], [entry(".wh.x", data=b"not empty")],
                        [entry(".wh.x", "symlink", target="x")],
                        [entry("same"), entry("same")], [entry("../escape")]):
            with self.subTest(entries=entries), self.assertRaises(ValueError):
                self.parse(entries)

    def test_hardlink_anchor_is_lexical_not_tar_order(self):
        result = self.parse([entry("z"), entry("a", "link", target="z"),
                             entry("b", "link", target="a")])
        self.assertNotIn("hardlink", result["a"])
        self.assertEqual(result["b"]["hardlink"], "a")
        self.assertEqual(result["z"]["hardlink"], "a")

    def test_replacing_alias_detaches_it_without_losing_old_inode(self):
        lower = [entry("z"), entry("a", "link", target="z"), entry("b", "link", target="z")]
        for name in ("a", "z"):
            with self.subTest(replaced=name):
                result = self.parse(lower, [entry(name, data=b"replacement")])
                aliases = sorted({"a", "b", "z"} - {name})
                self.assertNotIn("hardlink", result[name])
                self.assertNotIn("hardlink", result[aliases[0]])
                self.assertEqual(result[aliases[1]]["hardlink"], aliases[0])
                self.assertEqual(result[name]["sha256"], hashlib.sha256(b"replacement").hexdigest())
                self.assertEqual(result[aliases[0]]["sha256"], hashlib.sha256(b"data").hexdigest())

    def test_whiteout_of_hardlink_anchor_keeps_surviving_aliases(self):
        result = self.parse([entry("a"), entry("b", "link", target="a"),
                             entry("c", "link", target="b")], [entry(".wh.a", data=b"")])
        self.assertEqual(set(result), {"b", "c"})
        self.assertNotIn("hardlink", result["b"])
        self.assertEqual(result["c"]["hardlink"], "b")

    def test_opaque_whiteout_detaches_only_hidden_aliases(self):
        result = self.parse([entry("d", "directory"), entry("d/a"),
                             entry("outside", "link", target="d/a")],
                            [entry("d/.wh..wh..opq", data=b""), entry("d/a", data=b"new")])
        self.assertNotIn("hardlink", result["outside"])
        self.assertNotIn("hardlink", result["d/a"])
        self.assertNotEqual(result["outside"]["sha256"], result["d/a"]["sha256"])

    def test_nonlexical_hardlinks_match_real_extraction(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            layout = layout_at(base / "layout", [[entry("z"), entry("a", "link", target="z")]])
            expected, _ = metadata.oci_snapshot(layout)
            manifest, _ = metadata._manifest_from_layout(layout)
            layer = layout / "blobs/sha256" / manifest["layers"][0]["digest"].split(":")[1]
            extracted = base / "root"
            extracted.mkdir()
            with tarfile.open(layer) as archive:
                archive.extractall(extracted, filter="data")
            self.assertEqual(metadata.snapshot(extracted), expected)

    def test_device_numbers_from_real_device_stat(self):
        # /dev/null is an existing real device: this test needs no mknod rights.
        info = os.lstat("/dev/null")
        self.assertTrue(stat.S_ISCHR(info.st_mode))
        record = metadata._record(Path("/dev/null"), "null", info, {})
        expected = self.parse([entry("null", "char", devmajor=os.major(info.st_rdev),
                                    devminor=os.minor(info.st_rdev))])["null"]
        self.assertEqual((record["major"], record["minor"]), (expected["major"], expected["minor"]))

    def test_device_number_drift_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "root"
            root.mkdir()
            node = root / "device"
            try:
                os.mknod(node, stat.S_IFCHR | 0o600, os.makedev(1, 3))
            except PermissionError:
                self.skipTest("mknod requires privileges; also run in the privileged fixture")
            basis = root.parent / "basis.json"
            basis.write_text(json.dumps({"schema": 3, "layer_artifact": "fixture/device/key",
                                         "structure": metadata._structure(root), "entries": []}))
            sidecar = root.parent / "final.json"
            finalize_fixture(root, basis, "amd64", "default", sidecar)
            old = os.lstat(node)
            node.unlink()
            os.mknod(node, stat.S_IFCHR | 0o600, os.makedev(1, 5))
            os.utime(node, ns=(old.st_atime_ns, old.st_mtime_ns))
            # Keep directory metadata identical too: only device identity changes.
            with self.assertRaisesRegex(ValueError, "unexplained changes"):
                metadata.validate_exported(root, sidecar, None, None, None)


if __name__ == "__main__":
    unittest.main()
