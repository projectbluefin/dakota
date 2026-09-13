#!/usr/bin/env python3
"""Measure layer reuse between two local, compressed OCI layouts.

Both inputs must use the same compression policy. This measures image transfer
bytes, not registry HTTP/TLS overhead or client-specific partial pulls.
"""
import argparse
import json
from pathlib import Path

from scripts.ownership_metadata import _manifest_from_layout


def compare(old: Path, new: Path) -> dict:
    before, before_digest = _manifest_from_layout(old)
    after, after_digest = _manifest_from_layout(new)
    old_layers = {layer["digest"]: layer for layer in before["layers"]}
    new_layers = {layer["digest"]: layer for layer in after["layers"]}
    media = {item["mediaType"] for item in [*old_layers.values(), *new_layers.values()]}
    if len(media) != 1 or not next(iter(media)).endswith(("+gzip", "+zstd")):
        raise ValueError("layouts must use one identical compressed layer media type")
    shared = old_layers.keys() & new_layers.keys()
    added = new_layers.keys() - old_layers.keys()
    new_bytes = sum(new_layers[key]["size"] for key in added)
    config_bytes = after["config"]["size"] if after["config"]["digest"] != before["config"]["digest"] else 0
    manifest_bytes = (new / "blobs/sha256" / after_digest.split(":")[1]).stat().st_size if after_digest != before_digest else 0
    return {
        "old_manifest": before_digest, "new_manifest": after_digest,
        "old_layers": len(before["layers"]), "new_layers": len(after["layers"]),
        "shared_layers": len(shared), "added_layers": len(added),
        "old_compressed_layer_bytes": sum(v["size"] for v in old_layers.values()),
        "new_compressed_layer_bytes": sum(v["size"] for v in new_layers.values()),
        "shared_compressed_bytes": sum(new_layers[k]["size"] for k in shared),
        "new_layer_bytes": new_bytes, "new_config_bytes": config_bytes,
        "new_manifest_bytes": manifest_bytes,
        "transfer_bytes": new_bytes + config_bytes + manifest_bytes,
        "changed_layer_digests": sorted(added),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("old", type=Path)
    parser.add_argument("new", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = compare(args.old, args.new)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "changed_layer_digests"}, indent=2))


if __name__ == "__main__":
    main()
