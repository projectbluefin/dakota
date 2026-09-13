#!/usr/bin/env python3
"""Fail-closed ownership sidecar finalization and export validation.

Companion artifacts never enter the consumer root.  OCI script elements write a
final sidecar next to their OCI layout; export binds the resulting TSV to the
immutable Podman image ID before Chunkah may restore physical xattrs.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import stat
import sys
import tarfile
from decimal import Decimal, InvalidOperation
from pathlib import Path, PurePosixPath
from typing import Any, NoReturn

INTEGRATION_COMPONENT = "dakota.integration"
INTEGRATION_PRODUCER = "dakota:integration"
INTEGRATION_INTERVAL = "monthly"
SCHEMA = 3


def _fail(message: str) -> NoReturn:
    raise ValueError(message)


def _relative(path: str) -> str:
    if not isinstance(path, str) or not path.startswith("/") or "\t" in path or "\n" in path:
        _fail(f"invalid ownership path: {path!r}")
    result = path[1:]
    if not result or result.startswith("/") or any(part in ("", ".", "..") for part in result.split("/")):
        _fail(f"invalid ownership path: {path!r}")
    return result


def _safe_digest(path: Path, expected: os.stat_result) -> str:
    fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        current = os.fstat(fd)
        if not stat.S_ISREG(current.st_mode) or (current.st_dev, current.st_ino) != (expected.st_dev, expected.st_ino):
            _fail(f"file changed while hashing: {path}")
        digest = hashlib.sha256()
        while block := os.read(fd, 1024 * 1024):
            digest.update(block)
        return digest.hexdigest()
    finally:
        os.close(fd)


def _xattrs(path: Path, expected: os.stat_result) -> dict[str, str]:
    """Read every xattr without following symlinks, including capabilities."""
    values = {}
    for name in sorted(os.listxattr(path, follow_symlinks=False)):
        value = os.getxattr(path, name, follow_symlinks=False)
        values[name] = base64.b64encode(value).decode("ascii")
    current = os.lstat(path)
    if (current.st_dev, current.st_ino, stat.S_IFMT(current.st_mode)) != (
        expected.st_dev, expected.st_ino, stat.S_IFMT(expected.st_mode)
    ):
        _fail(f"path changed while reading xattrs: {path}")
    return values


def _record(path: Path, relative: str, info: os.stat_result, hardlinks: dict[tuple[int, int], str]) -> dict[str, Any]:
    record: dict[str, Any] = {
        "mode": stat.S_IMODE(info.st_mode),
        "uid": info.st_uid,
        "gid": info.st_gid,
        "mtime_ns": info.st_mtime_ns,
        "xattrs": _xattrs(path, info),
    }
    key = (info.st_dev, info.st_ino)
    if key in hardlinks:
        record["hardlink"] = hardlinks[key]
    else:
        hardlinks[key] = relative
    if stat.S_ISREG(info.st_mode):
        record.update(type="file", sha256=_safe_digest(path, info))
    elif stat.S_ISLNK(info.st_mode):
        record.update(type="symlink", target=os.readlink(path))
    elif stat.S_ISDIR(info.st_mode):
        record["type"] = "directory"
    elif stat.S_ISCHR(info.st_mode):
        record.update(type="character-device", major=os.major(info.st_rdev), minor=os.minor(info.st_rdev))
    elif stat.S_ISBLK(info.st_mode):
        record.update(type="block-device", major=os.major(info.st_rdev), minor=os.minor(info.st_rdev))
    elif stat.S_ISFIFO(info.st_mode):
        record["type"] = "fifo"
    elif stat.S_ISSOCK(info.st_mode):
        record["type"] = "socket"
    else:
        _fail(f"unknown filesystem type: {path}")
    return record


def snapshot(root: Path) -> dict[str, dict[str, Any]]:
    """lstat-only tree walk that never follows a symlink or metadata parent."""
    root_info = os.lstat(root)
    if not stat.S_ISDIR(root_info.st_mode) or stat.S_ISLNK(root_info.st_mode):
        _fail(f"root is not a real directory: {root}")
    result: dict[str, dict[str, Any]] = {}
    hardlinks: dict[tuple[int, int], str] = {}
    stack = [root]
    while stack:
        current = stack.pop()
        with os.scandir(current) as entries:
            for entry in sorted(entries, key=lambda item: item.name, reverse=True):
                path = Path(entry.path)
                info = os.lstat(path)
                relative = path.relative_to(root).as_posix()
                result[relative] = _record(path, relative, info, hardlinks)
                if stat.S_ISDIR(info.st_mode):
                    stack.append(path)
    # Hardlink ownership is inode-scoped. Canonicalize anchors by path rather
    # than filesystem traversal order so OCI tar link ordering cannot create a
    # false root mismatch.
    groups: dict[tuple[int, int], list[str]] = {}
    for relative, record in result.items():
        if record["type"] != "directory":
            info = os.lstat(root / relative)
            groups.setdefault((info.st_dev, info.st_ino), []).append(relative)
    for paths in groups.values():
        anchor = min(paths)
        for relative in paths:
            result[relative].pop("hardlink", None)
            if relative != anchor:
                result[relative]["hardlink"] = anchor
    return dict(sorted(result.items()))


def _canonical(value: Any) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def _read_regular(path: Path) -> bytes:
    try:
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        try:
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode):
                _fail(f"metadata is not a regular file: {path}")
            chunks = []
            while block := os.read(fd, 1024 * 1024):
                chunks.append(block)
            return b"".join(chunks)
        finally:
            os.close(fd)
    except OSError as error:
        _fail(f"cannot read metadata {path}: {error}")


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(_read_regular(path))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        _fail(f"cannot parse metadata {path}: {error}")
    if not isinstance(value, dict):
        _fail(f"metadata is not an object: {path}")
    return value


def _load_basis(path: Path) -> tuple[dict[str, dict[str, str]], dict[str, str], str, str]:
    raw = _read_regular(path)
    data = _read_json(path)
    if (
        data.get("schema") != SCHEMA
        or not isinstance(data.get("entries"), list)
        or not isinstance(data.get("structure"), dict)
        or not isinstance(data.get("layer_artifact"), str)
        or not data["layer_artifact"]
    ):
        _fail(f"unsupported basis schema: {path}")
    structure = data["structure"]
    if any(not isinstance(name, str) or not isinstance(kind, str) for name, kind in structure.items()):
        _fail(f"invalid basis structure: {path}")
    owners: dict[str, dict[str, str]] = {}
    for entry in data["entries"]:
        if not isinstance(entry, dict):
            _fail("basis contains non-object entry")
        relative = _relative(entry.get("path"))
        component, producer, interval = entry.get("component"), entry.get("producer"), entry.get("interval")
        if not all(
            isinstance(value, str) and value and "\t" not in value and "\n" not in value
            for value in (component, producer, interval)
        ):
            _fail(f"invalid basis owner: /{relative}")
        if relative in owners or structure.get(relative) not in ("file", "symlink"):
            _fail(f"duplicate or structurally invalid basis path: /{relative}")
        owners[relative] = {"component": component, "producer": producer, "interval": interval}
    eligible = {name for name, kind in structure.items() if kind in ("file", "symlink")}
    if set(owners) != eligible:
        _fail(f"basis lacks ownership entries (first: {sorted(eligible - set(owners))[:5]})")
    return owners, structure, data["layer_artifact"], hashlib.sha256(raw).hexdigest()


def _structure(root: Path) -> dict[str, str]:
    """Read path/type identity without hashing content or reading xattrs."""
    root_info = os.lstat(root)
    if not stat.S_ISDIR(root_info.st_mode) or stat.S_ISLNK(root_info.st_mode):
        _fail(f"root is not a real directory: {root}")
    result = {}
    stack = [root]
    while stack:
        current = stack.pop()
        with os.scandir(current) as entries:
            for entry in sorted(entries, key=lambda item: item.name, reverse=True):
                path = Path(entry.path)
                info = os.lstat(path)
                relative = path.relative_to(root).as_posix()
                if stat.S_ISREG(info.st_mode): kind = "file"
                elif stat.S_ISLNK(info.st_mode): kind = "symlink"
                elif stat.S_ISDIR(info.st_mode): kind = "directory"
                elif stat.S_ISCHR(info.st_mode): kind = "character-device"
                elif stat.S_ISBLK(info.st_mode): kind = "block-device"
                elif stat.S_ISFIFO(info.st_mode): kind = "fifo"
                elif stat.S_ISSOCK(info.st_mode): kind = "socket"
                else: _fail(f"unknown filesystem type: {path}")
                result[relative] = kind
                if kind == "directory":
                    stack.append(path)
    return dict(sorted(result.items()))


def verify_basis(root: Path, basis_path: Path) -> None:
    """Check that basis claims describe the real compose layer structure.

    Content deliberately is not compared here.  Artifact cache keys can have
    non-reproducible byte realizations (for example embedded temporary build
    paths) without changing ownership.  finalize_oci() binds the sidecar to the
    exact bytes, xattrs, and hardlink topology packaged by build-oci.
    """
    _, expected, _, _ = _load_basis(basis_path)
    actual = _structure(root)
    mismatches = [name for name in sorted(set(expected) | set(actual)) if expected.get(name) != actual.get(name)]
    if mismatches:
        _fail(f"ownership basis does not match real layer structure ({len(mismatches)} paths; first: {mismatches[:5]})")


def _oci_path(name: str) -> str:
    """Normalize an OCI tar member without permitting archive traversal."""
    while name.startswith("./"):
        name = name[2:]
    normalized = str(PurePosixPath(name))
    if not name or normalized == ".":
        return ""
    if name.startswith("/") or normalized != name or any(part in ("", ".", "..") for part in name.split("/")):
        _fail(f"unsafe OCI layer path: {name!r}")
    return normalized


def _tar_mtime_ns(member: tarfile.TarInfo) -> int:
    value = member.pax_headers.get("mtime", str(member.mtime))
    try:
        return int(Decimal(value) * 1_000_000_000)
    except InvalidOperation:
        _fail(f"invalid OCI layer mtime for {member.name!r}: {value!r}")


def _tar_xattrs(member: tarfile.TarInfo) -> dict[str, str]:
    result = {}
    prefix = "SCHILY.xattr."
    for key, value in member.pax_headers.items():
        if key.startswith(prefix):
            raw = value.encode("utf-8", "surrogateescape")
            result[key[len(prefix):]] = base64.b64encode(raw).decode("ascii")
    return dict(sorted(result.items()))


def _hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while block := source.read(1024 * 1024):
            digest.update(block)
    return digest.hexdigest()


def _remove_tree(tree: dict[str, dict[str, Any]], path: str) -> None:
    previous = tree.pop(path, None)
    # Replacing a leaf cannot remove descendants. This matters for large upper
    # layers: scanning the entire image for every replaced file is quadratic.
    if previous is not None and previous["type"] != "directory":
        return
    for candidate in [item for item in tree if item.startswith(path + "/")]:
        del tree[candidate]


def _manifest_from_layout(layout: Path) -> tuple[dict[str, Any], str]:
    index = _read_json(layout / "index.json")
    manifests = index.get("manifests")
    if not isinstance(manifests, list) or len(manifests) != 1 or not isinstance(manifests[0], dict):
        _fail("OCI layout must contain exactly one image manifest")
    descriptor = manifests[0]
    digest = descriptor.get("digest")
    if not isinstance(digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        _fail("OCI layout has an invalid image manifest digest")
    path = layout / "blobs/sha256" / digest.removeprefix("sha256:")
    if _hash_file(path) != digest.removeprefix("sha256:"):
        _fail("OCI image manifest blob digest does not match its descriptor")
    return _read_json(path), digest


def oci_snapshot(layout: Path) -> tuple[dict[str, dict[str, Any]], str]:
    """Snapshot the exact filesystem encoded by an OCI layout.

    build-oci intentionally normalizes generated mtimes and adds mount-point
    directories while writing its tar.  Reading the completed OCI artifact,
    rather than the pre-packaging source directory, binds metadata to what an
    OCI consumer actually receives.  Layer blob digests are verified before
    their records are trusted.
    """
    manifest, manifest_digest = _manifest_from_layout(layout)
    layers = manifest.get("layers")
    if not isinstance(layers, list) or not layers:
        _fail("OCI image manifest has no layers")
    tree: dict[str, dict[str, Any]] = {}
    for descriptor in layers:
        if not isinstance(descriptor, dict):
            _fail("OCI image has an invalid layer descriptor")
        digest = descriptor.get("digest")
        media_type = descriptor.get("mediaType")
        if not isinstance(digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
            _fail("OCI image has an invalid layer digest")
        if media_type != "application/vnd.oci.image.layer.v1.tar":
            _fail(f"ownership metadata requires an uncompressed OCI layer, got {media_type!r}")
        blob = layout / "blobs/sha256" / digest.removeprefix("sha256:")
        if _hash_file(blob) != digest.removeprefix("sha256:"):
            _fail(f"OCI layer blob digest does not match its descriptor: {digest}")
        with tarfile.open(blob, mode="r:") as archive:
            members = []
            seen = set()
            # OCI whiteouts affect ONLY lower layers, regardless of their order
            # in this tar. Apply all removals before introducing any new entries.
            for member in archive:
                relative = _oci_path(member.name)
                if not relative:
                    continue
                if relative in seen:
                    _fail(f"duplicate OCI layer path: {relative}")
                seen.add(relative)
                basename = PurePosixPath(relative).name
                parent = relative.rpartition("/")[0]
                if basename.startswith(".wh."):
                    if not member.isfile() or member.size != 0 or basename == ".wh.":
                        _fail(f"invalid OCI whiteout: {relative}")
                    if basename == ".wh..wh..opq":
                        if not parent:
                            tree.clear()
                        else:
                            for candidate in [item for item in tree if item.startswith(parent + "/")]:
                                del tree[candidate]
                    else:
                        target = f"{parent}/{basename[4:]}" if parent else basename[4:]
                        _remove_tree(tree, target)
                else:
                    members.append((relative, member))
            for relative, member in members:
                # Normal layers list each path once. Avoid an O(paths²) scan;
                # descendants can only exist when this path replaces one from
                # an earlier layer.
                if relative in tree:
                    # Overlaying one directory record updates its metadata; it
                    # does not make the directory opaque. Other type changes
                    # replace the path and any previous descendants.
                    if tree[relative].get("type") != "directory" or not member.isdir():
                        _remove_tree(tree, relative)
                record: dict[str, Any] = {
                    "mode": member.mode,
                    "uid": member.uid,
                    "gid": member.gid,
                    "mtime_ns": _tar_mtime_ns(member),
                    "xattrs": _tar_xattrs(member),
                }
                if member.isfile():
                    checksum = member.pax_headers.get("freedesktopsdk.checksum.sha256")
                    if not isinstance(checksum, str) or not re.fullmatch(r"[0-9a-f]{64}", checksum):
                        source = archive.extractfile(member)
                        if source is None:
                            _fail(f"cannot read OCI regular file: {relative}")
                        file_digest = hashlib.sha256()
                        while block := source.read(1024 * 1024):
                            file_digest.update(block)
                        checksum = file_digest.hexdigest()
                    record.update(type="file", sha256=checksum)
                elif member.issym():
                    record.update(type="symlink", target=member.linkname)
                elif member.islnk():
                    target = _oci_path(member.linkname)
                    target_record = tree.get(target)
                    if target_record is None or target_record.get("type") == "directory":
                        _fail(f"OCI hardlink target is unavailable: {relative} -> {target}")
                    # Aliases share an inode, not a target pathname. Replacing
                    # or whiteouting one alias in a later layer must not retarget
                    # surviving aliases to the new inode at that pathname.
                    target_record.update(record)
                    record = target_record
                elif member.isdir():
                    record["type"] = "directory"
                elif member.ischr():
                    record.update(type="character-device", major=member.devmajor, minor=member.devminor)
                elif member.isblk():
                    record.update(type="block-device", major=member.devmajor, minor=member.devminor)
                elif member.isfifo():
                    record["type"] = "fifo"
                else:
                    _fail(f"unsupported OCI layer file type: {relative}")
                tree[relative] = record
    groups: dict[int, list[str]] = {}
    for path, record in tree.items():
        if record["type"] != "directory":
            groups.setdefault(id(record), []).append(path)
    result = {path: dict(record) for path, record in tree.items()}
    for paths in groups.values():
        anchor = min(paths)
        for path in paths:
            if path != anchor:
                result[path]["hardlink"] = anchor
    return dict(sorted(result.items())), manifest_digest


def _final_payload(tree: dict[str, dict[str, Any]], owners: dict[str, dict[str, str]],
                   layer_artifact: str, basis_digest: str, arch: str, variant: str,
                   oci_manifest_digest: str) -> dict[str, Any]:
    entries = []
    for relative, record in tree.items():
        if record["type"] not in ("file", "symlink"):
            continue
        owner = owners.get(relative, {
            "component": INTEGRATION_COMPONENT,
            "producer": INTEGRATION_PRODUCER,
            "interval": INTEGRATION_INTERVAL,
        })
        entries.append({"path": "/" + relative, **owner})
    return {"schema": SCHEMA, "arch": arch, "variant": variant, "basis_sha256": basis_digest,
            "layer_artifact": layer_artifact, "oci_manifest_digest": oci_manifest_digest,
            "binding": "oci-layout",
            "snapshot_sha256": _canonical(tree), "snapshot": tree, "entries": entries}


def finalize_oci(layout: Path, root: Path, basis_path: Path, arch: str, variant: str, output: Path) -> None:
    owners, _basis_structure, layer_artifact, basis_digest = _load_basis(basis_path)
    tree, manifest_digest = oci_snapshot(layout)
    payload = _final_payload(tree, owners, layer_artifact, basis_digest, arch, variant, manifest_digest)
    release = root / "usr/lib/os-release"
    release_record = tree.get("usr/lib/os-release")
    if release_record and release_record.get("type") == "file" and release.is_file() and not release.is_symlink():
        if _safe_digest(release, os.lstat(release)) != release_record["sha256"]:
            _fail("packaged os-release differs from the source root")
        payload["os_release_lines"] = _release_lines(release)
    _write_json(output, payload)


def _write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not stat.S_ISREG(os.lstat(path).st_mode):
        _fail(f"refusing to overwrite non-regular metadata: {path}")
    path.write_text(json.dumps(data, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")


def _load_final(path: Path) -> dict[str, Any]:
    data = _read_json(path)
    required = {"schema", "arch", "variant", "basis_sha256", "layer_artifact", "oci_manifest_digest", "binding", "snapshot_sha256", "snapshot", "entries"}
    if data.get("schema") != SCHEMA or not required <= data.keys() or not isinstance(data["snapshot"], dict) or not isinstance(data["entries"], list):
        _fail(f"unsupported final metadata schema: {path}")
    if _canonical(data["snapshot"]) != data["snapshot_sha256"]:
        _fail(f"invalid final snapshot digest: {path}")
    return data


def _os_release_change(expected: dict[str, Any], actual: dict[str, Any]) -> bool:
    if expected.get("type") != actual.get("type") or expected.get("type") != "file":
        return False
    for key in ("mode", "uid", "gid", "mtime_ns", "hardlink", "xattrs"):
        if expected.get(key) != actual.get(key):
            return False
    # This validator is called after snapshots are computed; read values are
    # supplied as hashes, so compare actual files at the caller instead.
    return True


def _release_lines(path: Path) -> list[str]:
    try:
        return path.read_text(encoding="utf-8").splitlines(keepends=True)
    except UnicodeDecodeError:
        _fail(f"os-release is not UTF-8: {path}")


def _only_export_substitutions(old: list[str], actual_root: Path, expected: dict[str, Any], actual: dict[str, Any]) -> bool:
    if not _os_release_change(expected, actual):
        return False
    new = _release_lines(actual_root / "usr/lib/os-release")
    if len(old) != len(new):
        return False
    allowed = re.compile(r"^(VERSION_ID|IMAGE_VERSION)=.*(?:\n)?$")
    return all(left == right or (allowed.match(left) and allowed.match(right) and left.split("=", 1)[0] == right.split("=", 1)[0]) for left, right in zip(old, new))


def _validate_entries(entries: list[Any], actual: dict[str, Any]) -> list[dict[str, str]]:
    result, seen = [], set()
    for entry in entries:
        if not isinstance(entry, dict):
            _fail("final metadata contains non-object entry")
        relative = _relative(entry.get("path"))
        component, interval = entry.get("component"), entry.get("interval")
        if relative in seen or relative not in actual or actual[relative]["type"] not in ("file", "symlink"):
            _fail(f"invalid final ownership entry: /{relative}")
        if not all(isinstance(value, str) and value and "\t" not in value and "\n" not in value for value in (component, interval)):
            _fail(f"invalid owner for /{relative}")
        seen.add(relative)
        result.append({"path": "/" + relative, "component": component, "interval": interval})
    eligible = {path for path, record in actual.items() if record["type"] in ("file", "symlink")}
    if seen != eligible:
        _fail(f"metadata lacks ownership entries (first: {sorted(eligible - seen)[:5]})")
    # A physical xattr belongs to the inode, not the path.  Do not produce a
    # manifest whose order chooses a hidden winner for conflicting hardlinks.
    groups: dict[str, set[tuple[str, str]]] = {}
    for entry in result:
        record = actual[_relative(entry["path"])]
        anchor = record.get("hardlink", _relative(entry["path"]))
        groups.setdefault(anchor, set()).add((entry["component"], entry["interval"]))
    conflicts = [anchor for anchor, owners in groups.items() if len(owners) > 1]
    if conflicts:
        _fail(f"conflicting hardlink ownership (first: {conflicts[:5]})")
    return sorted(result, key=lambda entry: entry["path"])


def _check_identity(final: dict[str, Any], arch: str | None, variant: str | None) -> None:
    if arch is not None and final["arch"] != arch:
        _fail(f"metadata architecture {final['arch']!r} does not match {arch!r}")
    if variant is not None and final["variant"] != variant:
        _fail(f"metadata variant {final['variant']!r} does not match {variant!r}")


def _manifest_bytes(entries: list[dict[str, str]]) -> bytes:
    return ("# fakecap component manifest: path\\tcomponent\\tinterval\n" + "".join(
        f"{entry['path']}\t{entry['component']}\t{entry['interval']}\n" for entry in entries)).encode("utf-8")


def _write_manifest(entries: list[dict[str, str]], manifest: Path | None) -> None:
    if manifest:
        manifest.parent.mkdir(parents=True, exist_ok=True)
        manifest.write_bytes(_manifest_bytes(entries))


def prepare_chunkify_manifest(sidecar: Path, image_id: str, manifest: Path, output: Path) -> None:
    """Verify the TSV against its image-bound sidecar and freeze verified bytes.

    The caller supplies a private temporary output, consumed by fakecap-restore.
    Never reopen the mutable input TSV after validation. This is integrity
    checking within the local export handoff, not a signature/authenticity check.
    """
    if not re.fullmatch(r"[0-9a-f]{64}", image_id):
        _fail(f"invalid immutable image ID: {image_id!r}")
    final = _load_final(sidecar)
    if final["binding"] != "final-image" or final.get("image_id") != image_id:
        _fail("ownership sidecar is not bound to the requested image ID")
    expected = _manifest_bytes(_validate_entries(final["entries"], final["snapshot"]))
    if _read_regular(manifest) != expected:
        _fail("ownership TSV does not match the image-bound sidecar")
    with output.open("xb") as destination:
        destination.write(expected)


def rebind_exported(root: Path, source_sidecar: Path, image_id: str, arch: str | None,
                    variant: str | None, output: Path, manifest: Path | None) -> None:
    """Validate Podman's squash transition and bind its exact final root.

    Podman's RUN container creates an empty /sys mount point when squashing an
    otherwise /sys-less build-oci archive. This is accepted only at this one
    transition, with strict empty-directory metadata checks. All later
    validation uses the newly snapshotted immutable-image binding.
    """
    if not re.fullmatch(r"[0-9a-f]{64}", image_id):
        _fail(f"invalid immutable image ID: {image_id!r}")
    final = _load_final(source_sidecar)
    if final["binding"] != "oci-layout":
        _fail("source metadata is not bound to an OCI layout")
    _check_identity(final, arch, variant)
    expected, actual = final["snapshot"], snapshot(root)
    changed = [name for name in sorted(set(expected) | set(actual)) if expected.get(name) != actual.get(name)]
    remaining = set(changed)
    if "usr/lib/os-release" in remaining:
        if not _only_export_substitutions(final.get("os_release_lines", []), root,
                                          expected.get("usr/lib/os-release", {}),
                                          actual.get("usr/lib/os-release", {})):
            _fail("os-release export change is not an allowed VERSION_ID/IMAGE_VERSION substitution")
        remaining.remove("usr/lib/os-release")
    if "sys" in remaining:
        sys_record = actual.get("sys")
        sys_children = [path for path in actual if path.startswith("sys/")]
        required = {"type": "directory", "mode": 0o755, "uid": 0, "gid": 0, "xattrs": {}}
        if expected.get("sys") is not None or sys_children or not isinstance(sys_record, dict) or any(
            sys_record.get(key) != value for key, value in required.items()
        ):
            _fail("Podman export added an unexpected /sys tree")
        remaining.remove("sys")
    if remaining:
        _fail(f"exported root has unexplained changes: {sorted(remaining)[:10]}")
    manifest_entries = _validate_entries(final["entries"], actual)
    rebound = dict(final)
    rebound.update(binding="final-image", image_id=image_id, snapshot=actual,
                   snapshot_sha256=_canonical(actual))
    _write_json(output, rebound)
    _write_manifest(manifest_entries, manifest)


def validate_exported(root: Path, sidecar: Path, arch: str | None, variant: str | None, manifest: Path | None) -> None:
    final = _load_final(sidecar)
    _check_identity(final, arch, variant)
    expected, actual = final["snapshot"], snapshot(root)
    changed = [name for name in sorted(set(expected) | set(actual)) if expected.get(name) != actual.get(name)]
    if changed:
        _fail(f"exported root has unexplained changes: {changed[:10]}")
    manifest_entries = _validate_entries(final["entries"], actual)
    _write_manifest(manifest_entries, manifest)


def compare(legacy: Path, manifest: Path, output: Path) -> None:
    def records(path: Path) -> dict[str, tuple[str, str]]:
        result = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            if line and not line.startswith("#"):
                fields = line.split("\t")
                if len(fields) != 3:
                    _fail(f"malformed TSV row in {path}: {line!r}")
                result[_relative(fields[0])] = (fields[1], fields[2])
        return result
    old, new = records(legacy), records(manifest)
    changed = sorted(path for path in set(old) & set(new) if old[path] != new[path])
    _write_json(output, {"legacy_effective_paths": len(old), "generated_paths": len(new),
                         "legacy_only_paths": len(set(old) - set(new)), "generated_only_paths": len(set(new) - set(old)),
                         "owner_or_interval_changes": len(changed), "changed_paths": changed})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    verify = commands.add_parser("verify-basis"); verify.add_argument("--root", type=Path, required=True); verify.add_argument("--basis", type=Path, required=True)
    final_oci = commands.add_parser("finalize-oci"); final_oci.add_argument("--layout", type=Path, required=True); final_oci.add_argument("--root", type=Path, required=True); final_oci.add_argument("--basis", type=Path, required=True); final_oci.add_argument("--arch", required=True); final_oci.add_argument("--variant", required=True); final_oci.add_argument("--output", type=Path, required=True)
    rebind = commands.add_parser("rebind-exported"); rebind.add_argument("--root", type=Path, required=True); rebind.add_argument("--sidecar", type=Path, required=True); rebind.add_argument("--image-id", required=True); rebind.add_argument("--arch"); rebind.add_argument("--variant"); rebind.add_argument("--output", type=Path, required=True); rebind.add_argument("--manifest", type=Path)
    validate = commands.add_parser("validate-exported"); validate.add_argument("--root", type=Path, required=True); validate.add_argument("--sidecar", type=Path, required=True); validate.add_argument("--arch"); validate.add_argument("--variant"); validate.add_argument("--manifest", type=Path)
    prepare = commands.add_parser("prepare-chunkify"); prepare.add_argument("--sidecar", type=Path, required=True); prepare.add_argument("--image-id", required=True); prepare.add_argument("--manifest", type=Path, required=True); prepare.add_argument("--output", type=Path, required=True)
    comparison = commands.add_parser("compare"); comparison.add_argument("--legacy", type=Path, required=True); comparison.add_argument("--manifest", type=Path, required=True); comparison.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "verify-basis": verify_basis(args.root, args.basis)
        elif args.command == "finalize-oci": finalize_oci(args.layout, args.root, args.basis, args.arch, args.variant, args.output)
        elif args.command == "rebind-exported": rebind_exported(args.root, args.sidecar, args.image_id, args.arch, args.variant, args.output, args.manifest)
        elif args.command == "validate-exported": validate_exported(args.root, args.sidecar, args.arch, args.variant, args.manifest)
        elif args.command == "prepare-chunkify": prepare_chunkify_manifest(args.sidecar, args.image_id, args.manifest, args.output)
        else: compare(args.legacy, args.manifest, args.output)
    except (OSError, ValueError) as error:
        print(f"ownership metadata: {error}", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
