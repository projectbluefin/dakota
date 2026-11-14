#!/usr/bin/env python3
"""Adapt only Dakota's common source pin and assemble candidate provenance."""
import argparse
import json
import re
import subprocess
from pathlib import Path

import yaml


def sha(value):
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise argparse.ArgumentTypeError("expected full lowercase 40-hex commit SHA")
    return value


def image_identity(flavor, digest, ref):
    if flavor not in ("dakota", "dakota-nvidia", "dakota-gaming", "dakota-nvidia-gaming") or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest) or ref != f"ghcr.io/projectbluefin/{flavor}@{digest}":
        raise ValueError("invalid native candidate image identity")
    return dict(flavor=flavor, digest=digest, ref=ref)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("common_sha", type=sha)
    parser.add_argument("testsuite_sha", type=sha)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--source", type=Path)
    mode.add_argument("--image", nargs=3, metavar=("FLAVOR", "DIGEST", "REF"))
    mode.add_argument("--merge", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    consumer = sha(subprocess.check_output(["git", "rev-parse", "HEAD^{commit}"], text=True).strip())
    result = dict(common_sha=args.common_sha, consumer_sha=consumer, testsuite_sha=args.testsuite_sha)
    if args.source:
        actual = subprocess.check_output(["git", "-C", str(args.source), "rev-parse", "HEAD^{commit}"], text=True).strip()
        if actual != args.common_sha:
            parser.error("common checkout does not match requested commit")
        element = Path("elements/bluefin/common.bst")
        text = element.read_text()
        data = yaml.safe_load(text)
        sources = data["sources"]
        first = sources[0]
        if first.get("kind") != "git_repo" or first.get("url") != "github:projectbluefin/common.git" or first.get("track") != "main" or not isinstance(first.get("ref"), str):
            parser.error("common source shape drift")
        patches = [s.get("path") for s in sources if s.get("kind") == "patch"]
        if patches != ["patches/common/0002-ghostty-dual-theme.patch", "patches/common/0003-uwelcome-interactive-only.patch", "patches/common/0004-policy-drop-redhat-gpg-entries.patch", "patches/common/0006-fastfetch-drop-weekly-stats.patch"]:
            parser.error("common downstream patch shape drift")
        old = first["ref"]
        replacement, count = re.subn(r"(?m)^(  ref: )" + re.escape(old) + r"$", lambda match: match[1] + args.common_sha, text, count=1)
        if count != 1:
            parser.error("common ref is not a unique plain source scalar")
        expected = yaml.safe_load(text)
        expected["sources"][0]["ref"] = args.common_sha
        if yaml.safe_load(replacement) != expected:
            parser.error("adaptation changed more than common source ref")
        element.write_text(replacement)
        result.update(old_common_ref=old, new_common_ref=args.common_sha)
    elif args.image:
        result["images"] = [image_identity(*args.image)]
    elif args.merge:
        images = []
        for path in sorted(args.merge.rglob("image-*.json")):
            item = json.loads(path.read_text())
            if any(item.get(key) != result[key] for key in result):
                parser.error("candidate provenance mismatch")
            images.extend(image_identity(image["flavor"], image["digest"], image["ref"]) for image in item["images"])
        if sorted(image["flavor"] for image in images) != sorted(["dakota", "dakota-nvidia", "dakota-gaming", "dakota-nvidia-gaming"]):
            parser.error("all four unique native images are required")
        result["images"] = images
    args.output.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
