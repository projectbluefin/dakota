"""Which disks Bluefin can be installed on, and how one is partitioned.

The install daemon is the only judge of that: it lists the disks for the
application, and checks the chosen one again before it erases anything.
Nothing here talks to D-Bus, so it runs under the unit tests.

Three sources, each for what it knows best. systemd-repart partitions the
disk, so it says which devices it can partition. lsblk says what is on
them. The daemon says which ones the live session runs from.
"""
from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass

# What the message below says, in the units disks are sold in.
MIN_BYTES = 10 * 1000**3
LSBLK_COLUMNS = "NAME,TYPE,SIZE,RO,MODEL,SERIAL,WWN,TRAN,PTTYPE,FSTYPE"
REPART = "/usr/bin/systemd-repart"


def root_partition(encrypt: bool) -> str:
    """The systemd-repart definition of the root partition.

    Encrypted, it opens with the recovery key (the key file) and with the
    TPM. Either way the initramfs finds it by its partition type, so the
    loader entry names no root device.
    """
    definition = "[Partition]\nType=root\nLabel=root\nFormat=btrfs\n"
    return definition + ("Encrypt=key-file+tpm2\n" if encrypt else "")


class Refused(Exception):
    """The disk cannot be installed on. The message is shown to the user."""


@dataclass(frozen=True)
class Disk:
    name: str        # kernel name, such as "nvme0n1"
    ident: str       # what tells this disk from another that gets the same name
    model: str
    transport: str   # "usb", "nvme", "sata", ...
    size: int
    has_data: bool   # partitions, or a filesystem on the whole disk
    problem: str     # why it cannot be chosen, or ""


def lsblk() -> list[dict]:
    """The block device tree, whole disks at the top."""
    out = subprocess.run(
        ["lsblk", "--json", "--bytes", "--output", LSBLK_COLUMNS],
        capture_output=True, text=True, check=True).stdout
    return json.loads(out)["blockdevices"]


def parse_candidates(output: str) -> dict[str, int]:
    """{kernel name: disk sequence number} from ListCandidateDevices.

    One JSON object per device, each behind a record separator. The kernel
    gives a disk a new sequence number every time one is attached, so the
    number tells two disks apart that are alike in everything else.
    """
    found = {}
    for record in output.replace("\x1e", "\n").splitlines():
        if record.strip():
            device = json.loads(record)
            found[device["node"].removeprefix("/dev/")] = int(device["diskseq"])
    return found


def candidates() -> dict[str, int]:
    """The devices systemd-repart can partition, without empty drives."""
    r = subprocess.run(
        ["varlinkctl", "call", "--more", "--json=short", REPART,
         "io.systemd.Repart.ListCandidateDevices", '{"ignoreEmpty":true}'],
        capture_output=True, text=True)
    if r.returncode != 0:
        if "NoCandidateDevices" in r.stderr + r.stdout:
            return {}
        raise RuntimeError(f"systemd-repart: {(r.stderr or r.stdout).strip()}")
    return parse_candidates(r.stdout)


def _names(device: dict) -> set[str]:
    names = {device["name"]}
    for child in device.get("children", []):
        names |= _names(child)
    return names


def _true(value) -> bool:
    # lsblk prints booleans as true/false, older releases as "1"/"0".
    return value in (True, 1, "1")


def describe(tree: list[dict], in_use: set[str], partitionable: dict[str, int]) -> list[Disk]:
    """The disks to offer, from an lsblk tree.

    `in_use` holds the kernel names of the devices the live session runs
    from. A disk that carries one of them is the install media (or, after an
    install, the installed disk) and is left out. So is a drive with nothing
    in it, and everything that is not a whole disk.

    `partitionable` is what `candidates` returned. A disk that is not in it
    is left out too. A disk that is too small, or large enough and
    read-only, is shown with the reason and cannot be chosen.

    A disk has data when it has partitions or a filesystem. That is the line
    systemd-repart, bootc and GNOME's installer draw: a partition table
    without partitions is an empty disk.
    """
    disks = []
    for device in tree:
        name = device["name"]
        size = int(device.get("size") or 0)
        if device.get("type") != "disk" or not size or _names(device) & in_use:
            continue
        problem = ""
        if _true(device.get("ro")):
            # systemd-repart does not list these. The boot areas of an eMMC
            # are read-only disks of a few megabytes: nothing to tell.
            if size < MIN_BYTES:
                continue
            problem = "This disk is read-only."
        elif name not in partitionable:
            continue
        elif size < MIN_BYTES:
            problem = "This disk is too small. Bluefin needs at least 10 GB."
        model = (device.get("model") or "").strip()
        unique = device.get("wwn") or device.get("serial") or ""
        disks.append(Disk(
            name=name,
            ident=f"{partitionable.get(name, '')}|{unique}|{model}|{size}",
            model=model,
            transport=device.get("tran") or "",
            size=size,
            has_data=bool(device.get("fstype") or device.get("children")),
            problem=problem,
        ))
    return disks


def choose(disks: list[Disk], name: str, ident: str) -> Disk:
    """The disk the user confirmed, or Refused.

    The name alone is not enough: unplug one USB disk, plug in another, and
    the same name is a different disk. `ident` is what the user was shown.
    """
    for disk in disks:
        if disk.name != name:
            continue
        if disk.ident != ident:
            break
        if disk.problem:
            raise Refused(disk.problem)
        return disk
    raise Refused("The disks of this computer changed. Choose the disk again.")
