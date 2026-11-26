#!/usr/bin/env python3
"""Boot configuration and layout of Dakota's image-based installer medium.

After `bootc install to-disk --composefs-backend --bootloader systemd` has
written the deployment's Type #1 entry and loader.conf on the ESP,
build-raw-image.sh adds the live entry with:

  medium.py live-entry ENTRY OUT LIVE_INITRD [EXTRA_KARGS]
                                                 write the "Dakota Live" entry
  medium.py loader-conf LOADER_CONF ENTRY_ID     make ENTRY_ID systemd-boot's default

and shrink-raw-image.sh asks it where to cut the image once the root
filesystem has been shrunk to its content:

  medium.py shrink-plan SFDISK_JSON FS_BYTES     print "PARTNO SECTORS IMAGE_BYTES"
  medium.py shrunk-dump DUMP PARTNO SECTORS      the sfdisk dump to write after the cut

The live entry is the deployment's own entry with `ro dakota.live` in place
of `rw` and one more initrd: LIVE_INITRD, a cpio on the medium's ESP that
carries bootc's /usr/lib/composefs/setup-root-conf.toml: a tmpfs overlay over
/, with /etc and /var (bootc-root-setup.service mounts it itself, so no
ordering against it is needed). systemd-boot concatenates the initrds, and
later cpio members win, so only this entry boots live; the image and its
initramfs are untouched. This is GNOME OS's live addon idea for Type #1
entries: the live part lives only on the medium's ESP, and OS-Installer's
install.sh deletes the entry, the initrds only it loads and the loader.conf
default from the installed copy, and fails if any entry still carries
`dakota.live`.
"""

import json
import re
import sys
from pathlib import Path

LIVE_KARG = "dakota.live"
LIVE_TITLE = "Dakota Live (try or install)"
# systemd-boot sorts by sort-key first; "0" puts the live entry on top.
LIVE_SORT_KEY = "0-dakota-live"
LOADER_TIMEOUT = "5"
ALIGN_BYTES = 1024 * 1024
# Room after the last partition for the backup GPT (33 sectors), aligned.
GPT_TAIL_BYTES = ALIGN_BYTES


def live_entry(entry: str, live_initrd: str, extra_kargs: list[str] | None = None) -> str:
    """The live variant of a Type #1 entry's text."""
    extra = list(extra_kargs or [])
    out = []
    saw_options = saw_initrd = saw_sort_key = False
    for line in entry.splitlines():
        key, _, value = line.partition(" ")
        value = value.strip()
        if key == "title":
            line = f"title {LIVE_TITLE}"
        elif key == "sort-key":
            line = f"sort-key {LIVE_SORT_KEY}"
            saw_sort_key = True
        elif key == "options":
            saw_options = True
            args = [a for a in value.split() if a not in ("rw", "ro", LIVE_KARG)]
            line = "options " + " ".join(args + ["ro", LIVE_KARG] + extra)
        out.append(line)
        if key == "initrd":
            saw_initrd = True
    if not saw_options:
        raise ValueError("BLS entry has no options line")
    if not saw_initrd:
        raise ValueError("BLS entry has no initrd line")
    # The extra initrd goes right after the entry's own (later archives win).
    last = max(i for i, line in enumerate(out) if line.split(" ", 1)[0] == "initrd")
    out.insert(last + 1, f"initrd {live_initrd}")
    if not saw_sort_key:
        out.append(f"sort-key {LIVE_SORT_KEY}")
    return "\n".join(out) + "\n"


def loader_conf(current: str, entry_id: str) -> str:
    """loader.conf with entry_id as the default and a visible menu."""
    keep = [line for line in current.splitlines()
            if line.strip() and line.split()[0] not in ("default", "timeout")]
    return "\n".join(keep + [f"default {entry_id}.conf", f"timeout {LOADER_TIMEOUT}"]) + "\n"


def shrink_plan(table: dict, fs_bytes: int) -> tuple[int, int, int]:
    """Where to cut the medium once the root filesystem is fs_bytes long.

    table is `sfdisk --json` output. The root filesystem is the last
    partition (the installer grows it to fill the target), so the image keeps
    every byte up to the end of a partition just large enough for the
    filesystem, plus the backup GPT. Returns (partition number, new size in
    sectors, new image size in bytes).
    """
    pt = table["partitiontable"]
    sector = int(pt.get("sectorsize", 512))
    parts = sorted(pt["partitions"], key=lambda p: int(p["start"]))
    if not parts:
        raise ValueError("partition table is empty")
    last = parts[-1]
    align = ALIGN_BYTES // sector
    sectors = -(-fs_bytes // sector)
    sectors = -(-sectors // align) * align
    if sectors > int(last["size"]):
        raise ValueError(f"filesystem ({fs_bytes} bytes) does not fit the last partition")
    digits = ""
    for ch in reversed(last["node"]):
        if not ch.isdigit():
            break
        digits = ch + digits
    number = int(digits) if digits else len(parts)
    image_bytes = (int(last["start"]) + sectors) * sector + GPT_TAIL_BYTES
    return number, sectors, image_bytes


PART_LINE = re.compile(r"^(\S*?)(\d+)(\s*:\s*start=\s*\d+,\s*size=\s*)(\d+)(.*)$")


def shrunk_dump(dump: str, partno: int, sectors: int) -> str:
    """An `sfdisk --dump` of the medium with partition partno cut to sectors.

    Written back to the truncated file, sfdisk lays out a fresh primary and
    backup GPT for the new size while keeping the disk and partition UUIDs,
    types and names. `last-lba:` is dropped so sfdisk derives it from the
    file's new size instead of the old one.
    """
    out, found = [], False
    for line in dump.splitlines():
        if line.startswith("last-lba:"):
            continue
        m = PART_LINE.match(line)
        if m and int(m.group(2)) == partno:
            line = f"{m.group(1)}{m.group(2)}{m.group(3)}{sectors}{m.group(5)}"
            found = True
        out.append(line)
    if not found:
        raise ValueError(f"partition {partno} not in the dump")
    if "label: gpt" not in out:
        raise ValueError("not a GPT dump")
    return "\n".join(out) + "\n"


def main(argv: list[str]) -> int:
    if len(argv) >= 5 and argv[1] == "live-entry":
        extra = argv[5].split() if len(argv) > 5 else []
        Path(argv[3]).write_text(live_entry(Path(argv[2]).read_text(), argv[4], extra))
        return 0
    if len(argv) == 4 and argv[1] == "loader-conf":
        path = Path(argv[2])
        current = path.read_text() if path.exists() else ""
        path.write_text(loader_conf(current, argv[3]))
        return 0
    if len(argv) == 5 and argv[1] == "shrunk-dump":
        sys.stdout.write(shrunk_dump(Path(argv[2]).read_text(), int(argv[3]), int(argv[4])))
        return 0
    if len(argv) == 4 and argv[1] == "shrink-plan":
        table = json.loads(Path(argv[2]).read_text())
        print(*shrink_plan(table, int(argv[3])))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
