#!/usr/bin/env python3
"""Build the Dakota live ISO from the OCI image.

usage: build.py IMAGE_LAYOUT OUTPUT_DIR [IMAGE_REFERENCE]

IMAGE_REFERENCE is where the installed system looks for updates. It
defaults to the reference recorded in the layout.

The ISO holds two partitions. The ESP boots the image's own kernel and
initramfs. The other is a btrfs seed filesystem laid out like a bootc
composefs install: the composefs repository plus the deployment's /etc and
/var. The live session mounts that seed with a zram device on top, and the
installer moves the running filesystem onto the target disk.

The seed is mounted read-only ("ro"): the medium can be write-protected or
a disc, and the early-boot sprout step is what makes the root writable.

Everything here works on plain files, without root, mounts or loop devices.

Environment:
  WORK               scratch directory on disk (default /build)
  ROOT_WORK          where the seed's tree is assembled (default /tmp)
  INSTALLER_TREE     the tree iso/installer.bst built
  SOURCE_DATE_EPOCH  the date written into the filesystems (default 0)
  SEED_ZSTD_LEVEL    compression of the seed (default 3). Level 15, the
                     highest mkfs.btrfs takes, makes the ISO about 0.3 GB
                     smaller and takes about eight minutes longer.
"""
from __future__ import annotations

import hashlib
import json
import os
import platform
import re
import shutil
import stat
import subprocess
import sys
import tomllib
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
CFS = ["bootc", "internals", "cfs"]
VOLUME_ID = "DAKOTA-LIVE"
# Fixed so the same input gives the same image.
SEED_UUID = "6d0e59c1-7e2f-4b0f-9b7e-64616b6f7461"
REPART_SEED = "5d1c1b06-5a44-4a0d-8d6f-64616b6f7461"
# Units that must not run in the live session: updaters, first-boot jobs, and
# everything that writes to the ESP. The medium can be read-only, and a
# failing /boot automount takes down every service sandboxed against it.
# The swap file would be written into memory (the live filesystem's writable
# device is zram), and btrfs cannot remove a device that holds an active one.
LIVE_MASKS = [
    "bluefin-swapfile-init.service", "var-swap-swapfile.swap",
    "flatpak-preinstall.service", "dakota-secure-boot-update.service",
    "bluefin-remove-installer.service", "ublue-booted-image.service",
    "uupd.timer", "bootc-fetch-apply-updates.timer", "boot.automount",
    "efi.automount", "systemd-boot-random-seed.service",
    "systemd-boot-update.service",
]
# Firmware that boots the ESP from an optical disc can fail when it is larger
# than 256 MiB (GNOME OS holds its ISO to 240 MiB for the same reason).
ESP_MAX_MB = 256
EFI_NAMES = {"x86_64": ("x64", "BOOTX64.EFI"), "aarch64": ("aa64", "BOOTAA64.EFI")}
# What to take out of the image: the state that becomes the deployment, and
# the boot files for the ESP.
IMAGE_PATHS = [
    "/etc", "/var", "/usr/lib/modules/*/vmlinuz",
    "/usr/lib/modules/*/initramfs.img",
    "/usr/lib/modules/*/kernel/drivers/block/zram/zram.ko*",
    "/usr/lib/systemd/boot/efi/systemd-boot*.efi*", "/usr/lib/bootc/kargs.d",
    "/usr/lib/os-release",
]
REFERENCE = re.compile(r"[^/]+/.+:.+")
# A system account (below 1000) with SystemAccount=true in AccountsService:
# GDM then still offers initial setup when the live user logs out.
LIVE_ACCOUNT = {
    "passwd": "live:x:900:900:Bluefin Live:/home/live:/bin/bash",
    "group": "live:x:900:",
    "shadow": "live::20000:0:99999:7:::",
    "gshadow": "live:!::",
}


class BuildFailed(Exception):
    """The ISO cannot be built. The message says why."""


def step(title: str) -> None:
    print(f"== {title}", flush=True)


def run(command: list, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run([str(part) for part in command], check=True, **kwargs)


def tool(name: str, *arguments) -> None:
    """Run one of the helpers that sit next to this file."""
    run([sys.executable, TOOLS / name, *arguments])


# -- pure helpers --------------------------------------------------------

def layout_reference(index: dict) -> str:
    """The reference an OCI layout records for its image."""
    try:
        return index["manifests"][0]["annotations"]["org.opencontainers.image.ref.name"]
    except (KeyError, IndexError):
        return ""


def boot_image(pull_output: str) -> str:
    """The image id `cfs oci pull --bootable` reports as the boot image."""
    found = re.search(r"^Boot image: (\S+)$", pull_output, re.MULTILINE)
    if not found:
        raise BuildFailed("the composefs pull did not report a boot image")
    return found.group(1)


def origin_file(reference: str, boot_digest: str, manifest: str) -> str:
    """The deployment's .origin file, as bootc writes it."""
    return (
        "[origin]\n"
        f"container-image-reference = ostree-unverified-image:docker://{reference}\n"
        "\n[boot]\n"
        "boot_type = bls\n"
        f"digest = {boot_digest}\n"
        "\n[image]\n"
        f"manifest_digest = {manifest}\n"
    )


def kernel_arguments(directory: Path, architecture: str) -> list[str]:
    """The kernel arguments the image asks for in /usr/lib/bootc/kargs.d."""
    arguments: list[str] = []
    if not directory.is_dir():
        return arguments
    for path in sorted(directory.glob("*.toml")):
        with path.open("rb") as handle:
            settings = tomllib.load(handle)
        wanted = settings.get("match-architectures")
        if wanted and architecture not in wanted:
            continue
        arguments += settings.get("kargs", [])
    return arguments


def os_release(path: Path) -> dict[str, str]:
    values = {}
    for line in path.read_text().splitlines():
        key, separator, value = line.strip().partition("=")
        if separator:
            values[key] = value.strip("\"'")
    return values


def loader_entry(name: str, version: str, bootdir: str, image_id: str, arguments: list[str]) -> str:
    """The one boot entry of the ISO.

    The composefs digest is optional ("?"): the seed has no fs-verity, the
    installer turns it on.
    """
    masks = "".join(f" systemd.mask={unit}" for unit in LIVE_MASKS)
    return (
        f"title {name} Live\n"
        f"version {version}\n"
        f"linux /{bootdir}/vmlinuz\n"
        f"initrd /{bootdir}/initrd\n"
        f"initrd /{bootdir}/live.cpio\n"
        f"options root=LABEL=dakota-live rootfstype=btrfs ro dakota.live{masks}"
        f" systemd.firstboot=no {' '.join(arguments)} composefs.digest=?v1-sha512-12:{image_id}\n"
    )


def esp_megabytes(content_kb: int) -> int:
    """ESP size for the content: room for the FAT tables, rounded to 8 MiB."""
    return (content_kb // 1024 + 1 + 6 + 7) // 8 * 8


def apparent_kb(root: Path) -> int:
    """What `du -sk --apparent-size` reports: the sizes of the regular files
    and symbolic links below root, hard links once, rounded up to KiB."""
    seen = set()
    total = 0
    for directory, names, files in os.walk(root):
        for name in names + files:
            status = os.lstat(os.path.join(directory, name))
            if not (stat.S_ISREG(status.st_mode) or stat.S_ISLNK(status.st_mode)):
                continue
            if status.st_nlink > 1:
                if (status.st_dev, status.st_ino) in seen:
                    continue
                seen.add((status.st_dev, status.st_ino))
            total += status.st_size
    return -(-total // 1024)


def with_wheel_member(group: str, user: str) -> str:
    """The group file with `user` added to wheel."""
    lines = []
    for line in group.splitlines():
        fields = line.split(":")
        if fields[0] == "wheel" and len(fields) == 4:
            members = [member for member in fields[3].split(",") if member]
            if user not in members:
                fields[3] = ",".join(members + [user])
            line = ":".join(fields)
        lines.append(line)
    return "\n".join(lines) + "\n"


def with_automatic_login(config: str, user: str) -> str:
    """GDM's custom.conf with automatic login for `user`."""
    if re.search(r"^AutomaticLogin=", config, re.MULTILINE):
        return config
    if not re.search(r"^\[daemon\]$", config, re.MULTILINE):
        config = "[daemon]\n" + config
    return re.sub(r"^\[daemon\]$", f"[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin={user}",
                  config, count=1, flags=re.MULTILINE)


# -- files ---------------------------------------------------------------

def rewrite(path: Path, change) -> None:
    """Replace a file's text with change(text), keeping its mode.

    Some of these files are read-only or mode 000, and the build sandbox may
    lack the capability to write to them regardless.
    """
    mode = path.stat().st_mode & 0o7777
    path.chmod(mode | 0o600)
    path.write_text(change(path.read_text()))
    path.chmod(mode)


def overlay(source: Path, target: Path) -> None:
    """Copy the tree `source` over `target`, as `cp -a source/. target/`."""
    target.mkdir(parents=True, exist_ok=True)
    for entry in sorted(source.iterdir()):
        destination = target / entry.name
        if entry.is_dir() and not entry.is_symlink():
            overlay(entry, destination)
            continue
        if destination.is_symlink() or destination.exists():
            destination.unlink()
        if entry.is_symlink():
            destination.symlink_to(os.readlink(entry))
        else:
            shutil.copy2(entry, destination)
    shutil.copystat(source, target)


def sha256_of(*paths: Path) -> str:
    """The SHA-256 of the files' contents, one after the other."""
    digest = hashlib.sha256()
    for path in paths:
        with path.open("rb") as handle:
            while chunk := handle.read(1 << 20):
                digest.update(chunk)
    return digest.hexdigest()


def set_times(root: Path, epoch: int) -> None:
    """Give everything below root, and root, the same timestamp."""
    for directory, names, files in os.walk(root):
        for name in names + files:
            os.utime(os.path.join(directory, name), (epoch, epoch), follow_symlinks=False)
    os.utime(root, (epoch, epoch))


def make_readable(*roots: Path) -> None:
    """A sandbox without CAP_DAC_OVERRIDE cannot read mode 000 files such as
    /etc/shadow, and mkfs.btrfs has to. They stay root-only."""
    for root in roots:
        for directory, _, files in os.walk(root):
            for name in files:
                path = Path(directory, name)
                if path.is_symlink() or os.access(path, os.R_OK):
                    continue
                path.chmod((path.stat().st_mode & 0o7777) | 0o600)
                print(f"made owner-readable: {path}")


def live_session(etc: Path, var: Path, tree: Path) -> None:
    """Turn the image's /etc and /var into a live session.

    Lays down the tree that iso/installer.bst built (the installer, its
    service and the live user's settings) and adds the live user with
    automatic login. Everything here is live-session state, and cleanup.py
    removes it once the system is installed: the paths in the tree's
    cleanup-paths, the account and the automatic login.
    """
    overlay(tree / "etc", etc)
    overlay(tree / "var", var)
    for name, entry in LIVE_ACCOUNT.items():
        path = etc / name
        if not path.exists():
            if name == "gshadow":
                continue
            raise BuildFailed(f"the image has no /etc/{name}")
        rewrite(path, lambda text, entry=entry: text if re.search(r"^live:", text, re.MULTILINE)
                else text + entry + "\n")
    rewrite(etc / "group", lambda text: with_wheel_member(text, "live"))
    gdm = etc / "gdm/custom.conf"
    gdm.parent.mkdir(parents=True, exist_ok=True)
    if not gdm.exists():
        gdm.write_text("[daemon]\n")
    rewrite(gdm, lambda text: with_automatic_login(text, "live"))


# -- the build -----------------------------------------------------------

def build(image: Path, out: Path, reference: str) -> None:
    work = Path(os.environ.get("WORK", "/build"))
    # The composefs importer writes objects through O_TMPFILE, which the
    # BuildStream sandbox's FUSE root does not support and its tmpfs /tmp
    # does. So the tree that becomes the seed lives in memory until
    # mkfs.btrfs has packed it, and needs about the size of the image in RAM.
    root = Path(os.environ.get("ROOT_WORK", "/tmp")) / "dakota-live-root"
    epoch = int(os.environ.get("SOURCE_DATE_EPOCH", "0"))
    installer_tree = Path(os.environ.get("INSTALLER_TREE", "/usr/share/dakota-live-installer"))
    extracted = work / "x"
    esp = work / "esp"
    for directory in (root, extracted, esp, out):
        directory.mkdir(parents=True, exist_ok=True)

    step("image layout")
    tool("fix-layout.py", image, work / "image")
    image = work / "image"
    if not reference:
        reference = layout_reference(json.loads((image / "index.json").read_text()))
    if not REFERENCE.fullmatch(reference):
        raise BuildFailed(f"{reference!r} is not a registry reference; pass IMAGE_REFERENCE")
    print(f"updates come from: {reference}")

    step("composefs repository (no fs-verity; the installer enables it)")
    repository = root / "composefs"
    cfs = [*CFS, "--repo", repository]
    run([*cfs, "init", "--insecure"])
    pulled = run([*cfs, "oci", "pull", "--bootable", f"oci:{image}", "dakota:live"],
                 stdout=subprocess.PIPE, text=True).stdout
    print(pulled, end="")
    # The repository can hold the same image in more than one EROFS format;
    # the one the kernel command line names is the boot image.
    image_id = boot_image(pulled)
    if not (repository / "images" / image_id).exists():
        raise BuildFailed("boot image not found in the repository")
    listing = run([*cfs, "oci", "images", "--json"], stdout=subprocess.PIPE, text=True).stdout
    manifest = json.loads(listing)["images"][0]["manifest_digest"]
    print(f"image id: {image_id}")

    step("files taken from the image")
    dump = work / "dump"
    with dump.open("wb") as handle:
        run([*cfs, "oci", "dump", "dakota:live"], stdout=handle)
    tool("extract.py", dump, repository / "objects", extracted, *IMAGE_PATHS)
    # Present only in images built with Secure Boot signing.
    signed = subprocess.run(
        [sys.executable, str(TOOLS / "extract.py"), str(dump), str(repository / "objects"),
         str(extracted), "/usr/lib/dakota/secure-boot"], stderr=subprocess.DEVNULL).returncode == 0
    if not signed:
        print("image is not signed for Secure Boot")
    kernels = sorted((extracted / "usr/lib/modules").iterdir())
    if len(kernels) != 1:
        raise BuildFailed(f"expected one kernel in the image, found {len(kernels)}")
    kernel = kernels[0]
    vmlinuz, initrd = kernel / "vmlinuz", kernel / "initramfs.img"

    step("deployment state")
    deploy = root / "state/deploy" / image_id
    var = root / "state/os/default/var"
    for directory in (deploy, var.parent, root / "boot"):
        directory.mkdir(parents=True, exist_ok=True)
    shutil.move(extracted / "etc", deploy / "etc")
    shutil.move(extracted / "var", var)
    (deploy / "var").symlink_to("../../os/default/var")
    (deploy / f"{image_id}.origin").write_text(
        origin_file(reference, sha256_of(vmlinuz, initrd), manifest))
    repository.chmod(0o700)
    make_readable(deploy / "etc", var)

    step("live session and installer")
    live_session(deploy / "etc", var, installer_tree)

    step("seed filesystem")
    set_times(root, epoch)
    size_kb = apparent_kb(root)
    seed = work / "seed.btrfs"
    with seed.open("wb") as handle:
        handle.truncate((size_kb + size_kb // 5 + 524288) * 1024)
    # With SOURCE_DATE_EPOCH and DETERMINISTIC_SEED mkfs.btrfs (7.3 and later)
    # writes the same filesystem for the same tree: sorted walk, fixed times
    # and UUIDs derived from the filesystem UUID.
    run(["mkfs.btrfs", "-L", "dakota-live", "-U", SEED_UUID,
         "--compress", f"zstd:{os.environ.get('SEED_ZSTD_LEVEL', '3')}",
         "--rootdir", root, "--shrink", seed],
        env={**os.environ, "DETERMINISTIC_SEED": "1", "SOURCE_DATE_EPOCH": str(epoch)})
    tool("check-seed.py", seed)
    run(["btrfstune", "-S", "1", seed])
    shutil.rmtree(root)

    step("ESP")
    machine = platform.machine()
    if machine not in EFI_NAMES:
        raise BuildFailed(f"no boot loader name known for {machine}")
    efi, boot_name = EFI_NAMES[machine]
    bootdir = f"EFI/Linux/bootc_composefs-{image_id}"
    for directory in (esp / "EFI/BOOT", esp / bootdir, esp / "loader/entries"):
        directory.mkdir(parents=True, exist_ok=True)
    loader = extracted / f"usr/lib/systemd/boot/efi/systemd-boot{efi}.efi"
    signed_loader = loader.with_name(loader.name + ".signed")
    secure_boot = extracted / "usr/lib/dakota/secure-boot"
    if (secure_boot / f"shim{efi}.efi").exists() and signed_loader.exists():
        # Shim starts the loader under the name it was built with.
        shutil.copy(secure_boot / f"shim{efi}.efi", esp / "EFI/BOOT" / boot_name)
        shutil.copy(secure_boot / f"mm{efi}.efi", esp / "EFI/BOOT" / f"mm{efi}.efi")
        shutil.copy(signed_loader, esp / "EFI/BOOT" / f"grub{efi}.efi")
        shutil.copy(secure_boot / "dakota-secure-boot.der", esp / "Enroll Dakota Secure Boot key.cer")
    else:
        shutil.copy(loader, esp / "EFI/BOOT" / boot_name)
    shutil.copy(vmlinuz, esp / bootdir / "vmlinuz")
    shutil.copy(initrd, esp / bootdir / "initrd")

    # The extra initramfs that makes the live root writable. On an optical
    # disc the partitions appear through systemd's own systemd-loop@.service,
    # so that is all it has to do.
    hook = work / "hook"
    units = hook / "usr/lib/systemd/system"
    wants = units / "initrd-root-fs.target.wants"
    (hook / "usr/lib/dakota-live").mkdir(parents=True, exist_ok=True)
    wants.mkdir(parents=True, exist_ok=True)
    shutil.copy(TOOLS / "initrd/sprout", hook / "usr/lib/dakota-live")
    for module in sorted((kernel / "kernel/drivers/block/zram").glob("zram.ko*")):
        shutil.copy(module, hook / "usr/lib/dakota-live")
    for unit in sorted((TOOLS / "initrd").glob("*.service")):
        shutil.copy(unit, units)
    (wants / "dakota-live-sprout.service").symlink_to("../dakota-live-sprout.service")
    tool("mkcpio.py", hook, esp / bootdir / "live.cpio")

    release = os_release(extracted / "usr/lib/os-release")
    (esp / "loader/entries/dakota-live.conf").write_text(loader_entry(
        release.get("NAME", "Bluefin"), release.get("VERSION_ID", "0"), bootdir, image_id,
        kernel_arguments(extracted / "usr/lib/bootc/kargs.d", machine)))
    (esp / "loader/loader.conf").write_text("timeout 3\n")
    set_times(esp, epoch)

    step("disk image")
    esp_mb = esp_megabytes(apparent_kb(esp))
    if esp_mb > ESP_MAX_MB:
        initrd_mb = -(-(esp / bootdir / "initrd").stat().st_size // 1024**2)
        raise BuildFailed(
            f"The boot files need a {esp_mb} MiB ESP, more than the {ESP_MAX_MB} MiB that boots "
            f"from optical media. The initramfs is the large part: {initrd_mb} MiB.")
    definitions = work / "repart.d"
    definitions.mkdir(parents=True, exist_ok=True)
    (definitions / "10-esp.conf").write_text(
        "[Partition]\n"
        "Type=esp\n"
        "# Also the volume name MokManager shows when enrolling the key from disk.\n"
        "Label=DAKOTA\n"
        "Format=vfat\n"
        f"CopyFiles={esp}:/\n"
        f"SizeMinBytes={esp_mb}M\n"
        f"SizeMaxBytes={esp_mb}M\n")
    (definitions / "20-seed.conf").write_text(
        "[Partition]\n"
        "Type=root\n"
        "Label=dakota-live\n"
        f"CopyBlocks={seed}\n")
    with (out / "dakota-live.repart.json").open("wb") as handle:
        run(["systemd-repart", "--el-torito=yes", f"--el-torito-volume={VOLUME_ID}",
             "--el-torito-system=LINUX", "--el-torito-publisher=BLUEFIN",
             "--sector-size=512", f"--definitions={definitions}", "--empty=create",
             "--dry-run=no", "--size=auto", "--discard=no", "--offline=true", "--no-pager",
             f"--seed={REPART_SEED}", "--json=pretty", work / "disk.raw"],
            stdout=handle,
            # Without --invariant mkfs.fat stamps the volume label with the build time.
            env={**os.environ, "SYSTEMD_REPART_MKFS_OPTIONS_VFAT": "--invariant"})
    shutil.move(work / "disk.raw", out / "dakota-live.iso")
    (out / "dakota-live.json").write_text(json.dumps({
        "image_id": image_id, "manifest_digest": manifest,
        "image_reference": reference, "esp_mb": esp_mb}) + "\n")
    for produced in sorted(out.iterdir()):
        print(f"{produced.stat().st_size:>12}  {produced.name}")


def main(argv: list[str]) -> int:
    if len(argv) not in (3, 4):
        print(__doc__, file=sys.stderr)
        return 2
    try:
        build(Path(argv[1]), Path(argv[2]), argv[3] if len(argv) == 4 else "")
    except BuildFailed as failure:
        print(f"live ISO: {failure}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as failure:
        print(f"live ISO: {failure.cmd[0]} exited with {failure.returncode}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
