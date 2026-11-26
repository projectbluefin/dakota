#!/usr/bin/env python3
"""Measure the image-based installer's medium the way a user would get it.

  measure_medium.py RAW OUT_JSON [--formats zstd-3,zstd-19-long,xz-9] [--label NAME]

Records the raw image's apparent size (what `dd` writes), its allocated size
(what the sparse file occupies), and for each download format the compressed
size (the download), the time to compress and the time to decompress. The
compressed files are deleted again: CI media carry test credentials and are
never uploaded.

Formats:
  zstd-3         zstd -3 -T0, the fast baseline the spike reported
  zstd-19-long   zstd -19 --long=31 -T0 (decompress with --long=31)
  xz-9           xz -9 -T0
"""

import argparse
import json
import os
import subprocess
import time
from pathlib import Path

FORMATS = {
    "zstd-3": (["zstd", "-q", "-T0", "-3", "-c"], ["zstd", "-q", "-d", "-c"], ".zst"),
    "zstd-19-long": (["zstd", "-q", "-T0", "-19", "--long=31", "-c"],
                     ["zstd", "-q", "-d", "--long=31", "--memory=2048MB", "-c"], ".zst"),
    "xz-9": (["xz", "-q", "-T0", "-9", "-c"], ["xz", "-q", "-d", "-T0", "-c"], ".xz"),
}


def allocated_bytes(path: Path) -> int:
    return os.stat(path).st_blocks * 512


def run_to(cmd: list[str], src: Path, dst) -> float:
    start = time.monotonic()
    with open(src, "rb") as fin:
        subprocess.run(cmd, stdin=fin, stdout=dst, check=True)
    return round(time.monotonic() - start, 1)


def measure(raw: Path, formats: list[str], label: str = "") -> dict:
    out = {"label": label, "apparent_bytes": raw.stat().st_size, "allocated_bytes": allocated_bytes(raw),
           "formats": {}}
    for name in formats:
        if name not in FORMATS:
            raise ValueError(f"unknown format {name!r}; known: {', '.join(FORMATS)}")
        comp, decomp, suffix = FORMATS[name]
        packed = raw.with_name(raw.name + suffix)
        try:
            with open(packed, "wb") as fout:
                compress_s = run_to(comp, raw, fout)
            with open(os.devnull, "wb") as null:
                decompress_s = run_to(decomp, packed, null)
            out["formats"][name] = {"bytes": packed.stat().st_size, "compress_seconds": compress_s,
                                    "decompress_seconds": decompress_s}
        finally:
            packed.unlink(missing_ok=True)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("raw", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--formats", default="zstd-3,zstd-19-long,xz-9")
    ap.add_argument("--label", default="")
    args = ap.parse_args()
    result = measure(args.raw, [f for f in args.formats.split(",") if f], args.label)
    args.out.write_text(json.dumps(result, indent=1) + "\n")
    print(json.dumps(result, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
