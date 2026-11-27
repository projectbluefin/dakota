#!/usr/bin/env python3
"""Check the seed filesystem that mkfs.btrfs wrote.

usage: check-seed.py SEED_IMAGE

Two things can go wrong without mkfs.btrfs reporting them. The filesystem
can be inconsistent, which `btrfs check` finds. And the image can carry
space nothing uses: `mkfs.btrfs --shrink` only cuts the image off after the
last allocated chunk, so an empty chunk that stays, or a chunk that was
removed in front of a used one, is paid for in every download of the ISO.
"""
from __future__ import annotations

import subprocess
import sys

# A filesystem packed tight still has the unused ends of its last data and
# metadata chunks (335 MiB on a 4.8 GiB seed). One stray data chunk is 1 GiB.
UNUSED_LIMIT = 1024**3


def superblock(text: str) -> dict[str, int]:
    """The numeric fields of `btrfs inspect-internal dump-super`."""
    fields = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1].isdigit():
            fields[parts[0]] = int(parts[1])
    return fields


def unused_problem(fields: dict[str, int], limit: int = UNUSED_LIMIT) -> str:
    """Why the image is larger than its content warrants, or ''."""
    unused = fields["total_bytes"] - fields["bytes_used"]
    if unused <= limit:
        return ""
    return (f"the seed image holds {unused // 1024**2} MiB that nothing uses "
            f"(limit {limit // 1024**2} MiB): mkfs.btrfs --shrink did not "
            "remove the empty block groups")


def main(argv: list[str]) -> int:
    seed = argv[1]
    subprocess.run(["btrfs", "check", "--readonly", seed], check=True,
                   stdout=subprocess.DEVNULL)
    fields = superblock(subprocess.run(
        ["btrfs", "inspect-internal", "dump-super", seed],
        check=True, capture_output=True, text=True).stdout)
    problem = unused_problem(fields)
    if problem:
        print(problem, file=sys.stderr)
        return 1
    print(f"seed: {fields['total_bytes']} bytes, {fields['bytes_used']} used")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
