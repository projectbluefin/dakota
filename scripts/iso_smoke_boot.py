#!/usr/bin/env python3
"""Boot a live ISO or an installed disk in QEMU and wait for the desktop.

usage: iso_smoke_boot.py IMAGE [--media usb|cd|disk] [--timeout SECONDS] [--log FILE]

The image is started under UEFI with Secure Boot off: a live ISO the way a
USB stick boots (a read-only disk with a partition table) or as an optical
disc, an installed disk image as a plain disk (it is not written to). The
guest has no network.

The guest reports on the serial port, through units handed to systemd as
credentials (the image is not changed, and its kernel command line has no
serial console). The boot passes when the display manager has started and
is still running ten seconds later. It fails at once when the system drops
to emergency mode. Units that failed on the way are listed as warnings.

It needs qemu-system-x86_64, KVM and the edk2 firmware files, and it does not
log in or install anything.
"""
from __future__ import annotations

import argparse
import base64
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

FIRMWARE = [
    # (code, vars) as packaged by QEMU itself and by Debian/Ubuntu's ovmf.
    ("/usr/share/qemu/edk2-x86_64-code.fd", "/usr/share/qemu/edk2-i386-vars.fd"),
    ("/usr/share/OVMF/OVMF_CODE_4M.fd", "/usr/share/OVMF/OVMF_VARS_4M.fd"),
    ("/usr/share/OVMF/OVMF_CODE.fd", "/usr/share/OVMF/OVMF_VARS.fd"),
    ("/usr/share/edk2/ovmf/OVMF_CODE.fd", "/usr/share/edk2/ovmf/OVMF_VARS.fd"),
]
PREFIX = "dakota-boot-check:"
PASSED = f"{PREFIX} display manager is running"
EMERGENCY = f"{PREFIX} emergency mode"
FAILED_UNITS = f"{PREFIX} failed units"
END = f"{PREFIX} end"

# systemd-debug-generator turns these credentials into units and drop-ins.
CHECK_UNIT = f"""[Unit]
Description=Report the boot result on the serial port
Requires=display-manager.service
After=display-manager.service

[Service]
Type=oneshot
StandardOutput=file:/dev/ttyS0
ExecStartPre=/usr/bin/sleep 10
ExecStartPre=/usr/bin/systemctl is-active --quiet display-manager.service
ExecStart=/usr/bin/echo {FAILED_UNITS}
ExecStart=-/usr/bin/systemctl list-units --failed --no-legend --plain
ExecStart=/usr/bin/echo {END}
ExecStart=/usr/bin/echo {PASSED}
"""
EMERGENCY_UNIT = f"""[Unit]
Description=Report emergency mode on the serial port
DefaultDependencies=no

[Service]
Type=oneshot
StandardOutput=file:/dev/ttyS0
ExecStart=/usr/bin/echo {EMERGENCY}
"""
CREDENTIALS = {
    "systemd.extra-unit.dakota-boot-check.service": CHECK_UNIT,
    "systemd.extra-unit.dakota-boot-emergency.service": EMERGENCY_UNIT,
    "systemd.unit-dropin.graphical.target": "[Unit]\nWants=dakota-boot-check.service\n",
    "systemd.unit-dropin.emergency.target": "[Unit]\nWants=dakota-boot-emergency.service\n",
}


def credentials() -> list[str]:
    """The QEMU arguments that pass CREDENTIALS to the guest's systemd."""
    arguments = []
    for name, text in CREDENTIALS.items():
        encoded = base64.b64encode(text.encode()).decode()
        arguments += ["-smbios", f"type=11,value=io.systemd.credential.binary:{name}={encoded}"]
    return arguments


def failed_units(console: str) -> list[str]:
    """The failed units the guest listed, from the serial log."""
    if FAILED_UNITS not in console or END not in console:
        return []
    listing = console.split(FAILED_UNITS, 1)[1].split(END, 1)[0]
    return [line.split()[0] for line in listing.splitlines() if line.strip()]


def firmware() -> tuple[str, str]:
    for code, variables in FIRMWARE:
        if Path(code).exists() and Path(variables).exists():
            return code, variables
    sys.exit("no edk2/OVMF firmware found; install qemu's edk2 files or the ovmf package")


def command(iso: Path, media: str, code: str, variables: Path, serial: Path) -> list[str]:
    if media == "usb":
        # A virtio disk, not usb-storage: the firmware's reads from QEMU's
        # emulated USB stick return corrupt data in about one boot in three
        # on a nested-virtualization runner. The firmware and the image take
        # the same path either way: partition table, ESP, read-only medium.
        disk = ["-drive", f"if=none,id=iso,format=raw,readonly=on,file={iso}",
                "-device", "virtio-blk-pci,drive=iso,bootindex=1"]
    elif media == "cd":
        disk = ["-drive", f"if=none,id=iso,format=raw,readonly=on,media=cdrom,file={iso}",
                "-device", "ide-cd,drive=iso,bootindex=1"]
    else:
        # snapshot=on keeps the guest's writes out of the image file.
        disk = ["-drive", f"if=none,id=iso,format=raw,snapshot=on,file={iso}",
                "-device", "virtio-blk-pci,drive=iso,bootindex=1"]
    return [
        "qemu-system-x86_64", "-machine", "q35,accel=kvm", "-cpu", "host", "-smp", "4", "-m", "6G",
        "-drive", f"if=pflash,format=raw,unit=0,readonly=on,file={code}",
        "-drive", f"if=pflash,format=raw,unit=1,file={variables}",
        *disk,
        *credentials(),
        # No network: the guest runs an image under test, and a runner may
        # sit next to services that trust its network.
        "-nic", "none",
        "-display", "none", "-monitor", "none", "-serial", f"file:{serial}", "-no-reboot",
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("iso", type=Path)
    parser.add_argument("--media", choices=("usb", "cd", "disk"), default="usb")
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--log", type=Path, help="keep the serial log here")
    args = parser.parse_args()
    if not args.iso.is_file():
        sys.exit(f"{args.iso}: not a file")
    if shutil.which("qemu-system-x86_64") is None:
        sys.exit("qemu-system-x86_64 is not installed")
    code, variables_template = firmware()

    with tempfile.TemporaryDirectory() as tmp:
        variables = Path(tmp) / "vars.fd"
        shutil.copyfile(variables_template, variables)
        serial = Path(tmp) / "serial.log"
        serial.touch()
        process = subprocess.Popen(command(args.iso, args.media, code, variables, serial),
                                   stdin=subprocess.DEVNULL)
        started = time.monotonic()
        result = f"the desktop did not start within {args.timeout} seconds"
        try:
            while time.monotonic() - started < args.timeout:
                time.sleep(2)
                console = serial.read_text(errors="replace")
                if PASSED in console:
                    result = ""
                    break
                if EMERGENCY in console:
                    result = "the system dropped to emergency mode"
                    break
                if process.poll() is not None:
                    result = f"QEMU exited with status {process.returncode}"
                    break
        finally:
            process.terminate()
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                process.kill()
            if args.log:
                shutil.copyfile(serial, args.log)
        elapsed = int(time.monotonic() - started)
        console = serial.read_text(errors="replace")
        for unit in failed_units(console):
            print(f"::warning::{args.iso.name}: {unit} failed during boot")
        if result:
            print(console[-3000:], file=sys.stderr)
            print(f"FAIL ({args.media}): {result}", file=sys.stderr)
            return 1
        print(f"PASS ({args.media}): desktop after {elapsed} seconds")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
