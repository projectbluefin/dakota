#!/usr/bin/env python3
"""gen-filemap.py — generate usr/lib/chunkah/filemap.json for the dakota image.

Queries the local BST artifact cache (via ``just bst``) to build an exact
file → BST-element mapping across the entire dependency tree.  The output
is written to ``files/filemap.json`` and baked into the OCI image as
``usr/lib/chunkah/filemap.json`` so chunkah can auto-detect it.

Run from the dakota project root after ``just bst build oci/layers/bluefin.bst``.

Usage::

    python3 scripts/gen-filemap.py

    # Custom target (default: oci/layers/bluefin.bst):
    python3 scripts/gen-filemap.py --target oci/layers/bluefin.bst

    # Dry-run: print JSON to stdout instead of writing the file:
    python3 scripts/gen-filemap.py --dry-run
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

_ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;]*m")

def strip_ansi(s: str) -> str:
    return _ANSI_ESCAPE.sub("", s)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).parent.parent
OUTPUT_PATH = PROJECT_ROOT / "files" / "filemap.json"
DEFAULT_TARGET = "oci/layers/bluefin.bst"

# Heuristic update-cadence hints keyed on element-name substrings.
# First match wins; elements not matching any hint get "monthly".
INTERVAL_HINTS: list[tuple[str, str]] = [
    ("bluefin/",            "weekly"),
    ("gnome/gnome-shell",   "weekly"),
    ("gnome/mutter",        "weekly"),
    ("gnome/gdm",           "weekly"),
    ("gnome/nautilus",      "weekly"),
    ("gnome/",              "monthly"),
    ("freedesktop-sdk",     "monthly"),
]
DEFAULT_INTERVAL = "monthly"


def guess_interval(element: str) -> str:
    for hint, interval in INTERVAL_HINTS:
        if hint in element:
            return interval
    return DEFAULT_INTERVAL


# ---------------------------------------------------------------------------
# BST helpers
# ---------------------------------------------------------------------------

def bst(*args: str) -> str:
    """Run ``just bst <args>`` from the project root, return stdout."""
    cmd = ["just", "bst", *args]
    result = subprocess.run(
        cmd,
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"ERROR: {' '.join(cmd)}\n{result.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
    return result.stdout


def list_elements(target: str) -> list[str]:
    """Return all element names in the full dependency tree of *target*."""
    out = bst("show", "--format", "%{name}", "--deps", "all", target)
    # Filter to lines that look like BST element paths (end in .bst).
    # Some elements override the name variable (e.g. secure-boot key elements)
    # which causes %{name} to output the variable value instead.
    return [strip_ansi(line).strip() for line in out.splitlines()
            if strip_ansi(line).strip().endswith(".bst")]


def list_uncached_elements(target: str) -> list[str]:
    """Return element names in *target*'s tree whose artifact is not cached.

    An uncached element silently vanishes from `bst artifact list-contents`
    output, so a filemap generated against a partial cache drops whole
    components without any error (the 2026-09 regeneration lost 34 elements
    this way).  Callers must treat a non-empty result as fatal.
    """
    # The Justfile interpolates arguments into shell source, so avoid
    # whitespace in the format. Split from the right for junction names.
    out = bst("show", "--format", "%{name}:%{state}", "--deps", "all", target)
    uncached = []
    for raw_line in (strip_ansi(l).strip() for l in out.splitlines()):
        if ":" not in raw_line:
            continue
        name, state = raw_line.rsplit(":", 1)
        if name.endswith(".bst") and state.strip() != "cached":
            uncached.append(name)
    return uncached


def list_all_contents(elements: list[str]) -> dict[str, list[str]]:
    """Return {element_name: [absolute_paths]} for all *elements* in one call."""
    print(f"Querying artifact contents for {len(elements)} elements...", file=sys.stderr)
    out = bst("artifact", "list-contents", "--long", *elements)

    result: dict[str, list[str]] = defaultdict(list)
    current: str | None = None

    for raw_line in (strip_ansi(l) for l in out.splitlines()):
        line = raw_line.rstrip()
        if not line:
            continue
        if not line.startswith("\t"):
            # Element header: "bluefin/ghostty.bst:"
            current = line.strip().rstrip(":")
            continue
        if current is None:
            continue

        # Tab-indented entry: "\t-rwxr-xr-x  exe  32003936  usr/bin/ghostty"
        parts = line.split()
        if len(parts) < 4:
            continue
        ftype = parts[1]
        path = parts[3]

        # Skip directories and symlinks — only claim regular/executable files.
        if ftype in ("dir",):
            continue

        result[current].append("/" + path)

    return dict(result)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--target", default=DEFAULT_TARGET,
                        help=f"Top-level BST element (default: {DEFAULT_TARGET})")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print JSON to stdout instead of writing files/filemap.json")
    args = parser.parse_args()

    elements = list_elements(args.target)
    print(f"Found {len(elements)} elements in dependency tree.", file=sys.stderr)

    uncached = list_uncached_elements(args.target)
    if uncached:
        print(f"ERROR: {len(uncached)} elements have no cached artifact; "
              "a filemap generated now would silently drop them. "
              "Pull or build the full tree first.", file=sys.stderr)
        for name in uncached:
            print(f"  uncached: {name}", file=sys.stderr)
        return 1

    contents = list_all_contents(elements)

    # Elements to skip: OCI layer aggregations merge all deps' files and
    # would overwrite specific component claims.  Only skip oci/layers/* since
    # those are the true merge points; other oci/* elements are fine if present.
    SKIP_PREFIXES = ("oci/layers/",)

    filemap: dict = {}
    total_files = 0
    for element, files in sorted(contents.items()):
        if not files:
            continue
        if any(element.startswith(p) for p in SKIP_PREFIXES):
            continue
        filemap[element] = {
            "interval": guess_interval(element),
            "files": sorted(files),
        }
        total_files += len(files)

    print(f"Built filemap: {len(filemap)} components, {total_files} files.", file=sys.stderr)

    output = json.dumps(filemap, indent=2, ensure_ascii=False) + "\n"

    # Build TSV manifest for fakecap-restore (path -> component -> interval)
    manifest_lines = []
    for element, data in sorted(filemap.items()):
        interval = data["interval"]
        for fpath in data["files"]:
            manifest_lines.append(f"{fpath}\t{element}\t{interval}")
    manifest = "# fakecap component manifest: path\tcomponent\tinterval\n"
    manifest += "\n".join(sorted(manifest_lines)) + "\n"

    if args.dry_run:
        print(output)
    else:
        OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT_PATH.write_text(output, encoding="utf-8")
        print(f"Written to {OUTPUT_PATH}", file=sys.stderr)
        MANIFEST_PATH = OUTPUT_PATH.parent / "fakecap-manifest.tsv"
        MANIFEST_PATH.write_text(manifest, encoding="utf-8")
        print(f"Written to {MANIFEST_PATH}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
