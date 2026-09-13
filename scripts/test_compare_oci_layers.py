"""Offline regression coverage for compressed image transfer accounting."""
import gzip
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from scripts.compare_oci_layers import compare
from scripts.ownership_metadata import _manifest_from_layout
from scripts.test_ownership_oci import entry, layout_at


def compressed_layout(path, contents, config=b"{}"):
    layout_at(path, [[entry("file", data=data)] for data in contents])
    manifest, _ = _manifest_from_layout(path)
    blobs = path / "blobs/sha256"

    def blob(raw, media):
        digest = hashlib.sha256(raw).hexdigest()
        (blobs / digest).write_bytes(raw)
        return {"digest": "sha256:" + digest, "size": len(raw), "mediaType": media}

    manifest["layers"] = [blob(gzip.compress((blobs / layer["digest"].split(":")[1]).read_bytes(), mtime=0),
                               "application/vnd.oci.image.layer.v1.tar+gzip") for layer in manifest["layers"]]
    manifest["config"] = blob(config, "application/vnd.oci.image.config.v1+json")
    descriptor = blob(json.dumps(manifest).encode(), "application/vnd.oci.image.manifest.v1+json")
    (path / "index.json").write_text(json.dumps({"schemaVersion": 2, "manifests": [descriptor]}))
    return path


class LayerComparisonTests(unittest.TestCase):
    def test_identical_layout_needs_no_new_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old = compressed_layout(root / "old", [b"one", b"two"])
            new = compressed_layout(root / "new", [b"one", b"two"])
            result = compare(old, new)
            self.assertEqual(result["shared_layers"], 2)
            self.assertEqual(result["added_layers"], 0)
            self.assertEqual(result["transfer_bytes"], 0)

    def test_changed_layer_and_config_accounting(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old = compressed_layout(root / "old", [b"one", b"two"])
            config = b'{"config":{"Labels":{"fixture":"changed"}}}'
            new = compressed_layout(root / "new", [b"one", b"three"], config)
            manifest, digest = _manifest_from_layout(new)
            result = compare(old, new)
            self.assertEqual(result["shared_layers"], 1)
            self.assertEqual(result["added_layers"], 1)
            self.assertEqual(result["new_layer_bytes"], manifest["layers"][1]["size"])
            self.assertEqual(result["new_config_bytes"], len(config))
            self.assertEqual(result["transfer_bytes"], manifest["layers"][1]["size"] + len(config)
                             + (new / "blobs/sha256" / digest.split(":")[1]).stat().st_size)

    def test_rejects_uncompressed_or_mixed_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            plain = layout_at(root / "plain", [[entry("file")]])
            compressed = compressed_layout(root / "compressed", [b"data"])
            for old, new in [(plain, plain), (plain, compressed)]:
                with self.subTest(old=old, new=new), self.assertRaisesRegex(ValueError, "compressed"):
                    compare(old, new)


if __name__ == "__main__":
    unittest.main()
