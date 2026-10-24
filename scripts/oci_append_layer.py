#!/usr/bin/env python3
"""Append one additive layer to a single-image OCI layout.

build-oci's parent mode diffs a full root against its parent and writes
whiteouts for every parent file missing from each directory the new layer
touches, so it cannot add a thin layer. This copies the base layout's layers
unchanged, adds one layer built by freedesktop-sdk's own layer writer with no
lowers (so it has no whiteouts), and copies the base config, manifest and
index entry as they are, appending only the new layer, its diff ID and one
history entry.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import shutil
import sys
import tarfile
import tempfile
from pathlib import Path
from typing import Any, NoReturn

LAYER_MEDIA_TYPE = "application/vnd.oci.image.layer.v1.tar"


def _fail(message: str) -> NoReturn:
    raise ValueError(message)


def _blob(layout: Path, digest: str) -> Path:
    if not isinstance(digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        _fail(f"invalid blob digest: {digest!r}")
    return layout / "blobs/sha256" / digest.removeprefix("sha256:")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while block := source.read(1024 * 1024):
            digest.update(block)
    return digest.hexdigest()


def _read_blob(layout: Path, descriptor: dict[str, Any]) -> dict[str, Any]:
    path = _blob(layout, descriptor.get("digest"))
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != descriptor["digest"].removeprefix("sha256:"):
        _fail(f"blob does not match its digest: {descriptor['digest']}")
    value = json.loads(data)
    if not isinstance(value, dict):
        _fail(f"blob is not a JSON object: {descriptor['digest']}")
    return value


def _write_blob(output: Path, data: bytes, media_type: str) -> dict[str, Any]:
    digest = hashlib.sha256(data).hexdigest()
    (output / "blobs/sha256" / digest).write_bytes(data)
    return {"mediaType": media_type, "digest": "sha256:" + digest, "size": len(data)}


def _place(source: Path, destination: Path) -> None:
    # Base layers are gigabytes; a hard link avoids copying them when the
    # staged base and the install root share a filesystem.
    try:
        os.link(source, destination)
    except OSError:
        shutil.copyfile(source, destination)


def append_layer(base: Path, layer_tar: Path, output: Path, comment: str) -> dict[str, Any]:
    """Write base + layer_tar to output; return the new manifest descriptor."""
    index = json.loads((base / "index.json").read_text(encoding="utf-8"))
    manifests = index.get("manifests")
    if not isinstance(manifests, list) or len(manifests) != 1:
        _fail("base layout must contain exactly one image manifest")
    manifest = _read_blob(base, manifests[0])
    config = _read_blob(base, manifest["config"])
    layers = manifest.get("layers")
    diff_ids = config.get("rootfs", {}).get("diff_ids")
    if not isinstance(layers, list) or not layers or not isinstance(diff_ids, list) or len(diff_ids) != len(layers):
        _fail("base image has inconsistent layers and diff IDs")
    if any(layer.get("mediaType") != LAYER_MEDIA_TYPE for layer in layers):
        _fail("base image layers must be uncompressed OCI tars")

    (output / "blobs/sha256").mkdir(parents=True, exist_ok=True)
    for layer in layers:
        source = _blob(base, layer["digest"])
        if _sha256(source) != layer["digest"].removeprefix("sha256:"):
            _fail(f"base layer does not match its digest: {layer['digest']}")
        _place(source, _blob(output, layer["digest"]))

    layer_digest = _sha256(layer_tar)
    destination = output / "blobs/sha256" / layer_digest
    shutil.copyfile(layer_tar, destination)
    new_layer = {"mediaType": LAYER_MEDIA_TYPE, "digest": "sha256:" + layer_digest,
                 "size": destination.stat().st_size}

    new_config = copy.deepcopy(config)
    new_config["rootfs"]["diff_ids"] = diff_ids + ["sha256:" + layer_digest]
    new_config["history"] = list(config.get("history", [])) + [{"comment": comment}]
    config_descriptor = _write_blob(output, json.dumps(new_config).encode(), manifest["config"]["mediaType"])

    new_manifest = copy.deepcopy(manifest)
    new_manifest["layers"] = layers + [new_layer]
    new_manifest["config"] = config_descriptor
    descriptor = _write_blob(output, json.dumps(new_manifest).encode(), manifests[0]["mediaType"])
    # Platform and the bootc origin annotation come from the base entry.
    for key in ("platform", "annotations"):
        if key in manifests[0]:
            descriptor[key] = copy.deepcopy(manifests[0][key])

    new_index = copy.deepcopy(index)
    new_index["manifests"] = [descriptor]
    (output / "index.json").write_text(json.dumps(new_index), encoding="utf-8")
    (output / "oci-layout").write_text(json.dumps({"imageLayoutVersion": "1.0.0"}), encoding="utf-8")
    return descriptor


def build_layer_tar(upper: Path, destination: Path) -> None:
    """Tar upper with freedesktop-sdk's layer writer and no lowers."""
    from oci_builder.layer_builder import create_layer  # staged by components/oci-builder.bst

    with tarfile.open(destination, mode="w:") as archive:
        create_layer(archive, str(upper), [])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--upper", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--comment", required=True)
    args = parser.parse_args()
    try:
        args.output.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=args.output) as scratch:
            layer = Path(scratch) / "layer.tar"
            build_layer_tar(args.upper, layer)
            append_layer(args.base, layer, args.output, args.comment)
    except (OSError, ValueError, KeyError) as error:
        print(f"oci append layer: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
