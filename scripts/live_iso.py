#!/usr/bin/env python3
"""Build the live ISO into .build-iso/ (the `just iso` recipe).

usage: live_iso.py [IMAGE ORIGIN]

Without arguments the ISO comes from oci/bluefin.bst, entirely inside
BuildStream (iso/live.bst). That is the form for local work.

With IMAGE and ORIGIN it comes from an exported or published image. IMAGE is
anything skopeo reads; ORIGIN is the reference the installed system updates
from. BuildStream then only supplies the tools (iso/tools.bst) as a sandbox,
and files/live-iso/build.py runs inside it.
"""
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / ".build-iso"
# registry/name:tag, the form bootc records as the image to update from.
ORIGIN = re.compile(r"[a-z0-9.-]+(/[a-z0-9._-]+)+:[A-Za-z0-9._-]+")
# The date written into the filesystems, so the same input gives the same ISO.
SOURCE_DATE_EPOCH = "1321009871"


def origin_problem(origin: str) -> str:
    """Why ORIGIN cannot be used, or an empty string."""
    if ORIGIN.fullmatch(origin):
        return ""
    return f"ORIGIN must be registry/name:tag, not {origin!r}"


def sandbox_command(origin: str) -> list[str]:
    """The `just bst shell` call that runs build.py on the copied image.

    The sandbox root is read-only, so every path the build writes is a mount
    of a directory under .build-iso (seen as /src/.build-iso in the
    BuildStream container).
    """
    mounts: list[str] = []
    for host, inside in (("image", "/image"), ("work", "/build"), ("out", "/out")):
        mounts += ["--mount", f"/src/.build-iso/{host}", inside]
    return [
        "just", "bst", "shell", *mounts, "iso/tools.bst", "--",
        "env", "WORK=/build", "ROOT_WORK=/build", "TMPDIR=/build",
        f"SOURCE_DATE_EPOCH={SOURCE_DATE_EPOCH}",
        "python3", "/usr/libexec/dakota-live-iso/build.py", "/image", "/out", origin,
    ]


def run(command: list[str]) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, cwd=ROOT, check=True)


def build_from_buildstream() -> None:
    run(["just", "bst", "build", "iso/live.bst"])
    run(["just", "bst", "artifact", "checkout", "iso/live.bst", "--deps", "none",
         "--directory", "/src/.build-iso"])


def build_from_image(image: str, origin: str) -> None:
    for name in ("work", "out"):
        (OUT / name).mkdir(parents=True)
    # --preserve-digests: the installed system records the manifest digest,
    # and it has to be the one the registry serves.
    run(["skopeo", "copy", "--preserve-digests", image, f"oci:{OUT / 'image'}:{origin}"])
    run(["just", "bst", "build", "iso/tools.bst"])
    run(sandbox_command(origin))
    for produced in (OUT / "out").iterdir():
        shutil.move(produced, OUT / produced.name)
    for name in ("work", "out", "image"):
        shutil.rmtree(OUT / name)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("image", nargs="?", default="")
    parser.add_argument("origin", nargs="?", default="")
    args = parser.parse_args(argv)
    if args.image:
        problem = origin_problem(args.origin)
        if problem:
            print(f"usage: just iso IMAGE ORIGIN. {problem}", file=sys.stderr)
            return 1
    shutil.rmtree(OUT, ignore_errors=True)
    try:
        if args.image:
            build_from_image(args.image, args.origin)
        else:
            build_from_buildstream()
    except subprocess.CalledProcessError as error:
        print(f"live ISO build failed: {error.cmd[0]} exited with {error.returncode}", file=sys.stderr)
        return 1
    for produced in sorted(OUT.iterdir()):
        print(f"{produced.stat().st_size:>12}  {produced.name}")
    print((OUT / "dakota-live.json").read_text())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
