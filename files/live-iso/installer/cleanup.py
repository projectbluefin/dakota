#!/usr/bin/python3
"""Remove what the live ISO added, on the first boot of the installed system.

dakota-live-cleanup.service runs this once the install daemon has left its
marker. The list of paths was written when the ISO was built
(iso/installer.bst), and it names this script and its unit too, so nothing
of the live session stays behind.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys

LIST = "/var/opt/dakota-installer/cleanup-paths"
MARKER = "/etc/dakota-live-cleanup-pending"
ROOTS = ("/etc/", "/var/")


def removable(path: str) -> bool:
    """Only plain absolute paths below /etc or /var are ever removed."""
    return path.startswith(ROOTS) and os.path.normpath(path) == path


def remove(path: str) -> None:
    if os.path.isdir(path) and not os.path.islink(path):
        shutil.rmtree(path, ignore_errors=True)
    elif os.path.lexists(path):
        os.unlink(path)


def main() -> int:
    with open(LIST) as listing:
        paths = [line.rstrip("\n") for line in listing if line.strip()]
    failed = False
    result = subprocess.run(["userdel", "--remove", "live"],
                            capture_output=True, text=True)
    # 6: the account is already gone.
    if result.returncode not in (0, 6):
        print(f"userdel: {result.stderr.strip()}", file=sys.stderr)
        failed = True
    for path in paths:
        if not removable(path):
            print(f"not removing {path!r}", file=sys.stderr)
            failed = True
            continue
        try:
            remove(path)
        except OSError as error:
            print(f"{path}: {error}", file=sys.stderr)
            failed = True
    os.unlink(MARKER)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
