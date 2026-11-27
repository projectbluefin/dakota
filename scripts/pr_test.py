#!/usr/bin/env python3
"""Steps of the pr-test job in build.yml, and the ISO cleanup in pr-cleanup.yml.

usage: pr_test.py COMMAND [options]

  prepare       install the tools the tests need and log in to GHCR
  resolve       find the digest :pr-N points at and check its revision
  boot-disk     install the image to a disk with bootc and boot that disk
  iso-changed   report whether the pull request changes the live ISO
  build-iso     build the live ISO from the pushed image and boot it
  upload-iso    upload a booted ISO and its checksum to R2
  delete-isos   remove a pull request's ISOs from R2

Each command is one workflow step. Values a later step needs go to
$GITHUB_OUTPUT, results a person reads go to $GITHUB_STEP_SUMMARY.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Ubuntu package for each tool, and a file that shows it is installed. A
# runner image that already carries them skips the package manager.
TOOLS = {
    "skopeo": "/usr/bin/skopeo",
    "qemu-system-x86": "/usr/bin/qemu-system-x86_64",
    "ovmf": "/usr/share/OVMF/OVMF_CODE_4M.fd",
    "rclone": "/usr/bin/rclone",
}
# A change under one of these means the ISO itself may have changed.
ISO_PATHS = re.compile(r"(elements/iso/|files/live-iso/|patches/btrfs-progs/|scripts/(iso_smoke_boot|live_iso|pr_test)\.py$)")
DIGEST = re.compile(r"sha256:[0-9a-f]{64}")
# Above this the ESP may not boot from optical media; build.py enforces it too.
ESP_LIMIT_MB = 256
# The bucket projectbluefin/dakota-iso publishes to, and where it is served.
R2_BUCKET = "R2:testing"
PUBLIC_URL = "https://projectbluefin.dev"
REVISION_LABEL = "org.opencontainers.image.revision"
LSBLK_PROFILE = Path("/etc/apparmor.d/lsblk")


# ── Decisions, kept free of side effects so they can be tested ─────────────

def iso_changed(paths: list[str]) -> bool:
    return any(ISO_PATHS.match(path) for path in paths)


def iso_name(image: str, tag: str) -> str:
    """dakota-pr-12.iso for ghcr.io/projectbluefin/dakota and pr-12."""
    return f"{image.rsplit('/', 1)[-1]}-{tag}.iso"


def iso_objects(images: list[str], tag: str) -> list[str]:
    """Every object a pull request's ISOs occupy in the bucket."""
    names = [iso_name(image, tag) for image in images]
    return [name + suffix for name in names for suffix in ("", "-CHECKSUM")]


def image_problem(inspect: dict, head_sha: str) -> str:
    """Why the inspected image cannot be the one this run pushed, or ''."""
    digest = inspect.get("Digest", "")
    if not DIGEST.fullmatch(digest):
        return "the registry returned no usable digest"
    # pr-image labels every image it pushes. A tag without the label, or
    # with another commit, is one an earlier run left behind.
    revision = (inspect.get("Labels") or {}).get(REVISION_LABEL, "")
    if revision != head_sha:
        return f"it was built from {revision or 'an unknown commit'}, not {head_sha}"
    return ""


def metadata_problem(metadata: dict, digest: str, origin: str) -> str:
    """Why an ISO's metadata does not describe the pushed image, or ''."""
    if metadata.get("manifest_digest") != digest:
        return f"it carries {metadata.get('manifest_digest')}, not {digest}"
    if metadata.get("image_reference") != origin:
        return f"it updates from {metadata.get('image_reference')}, not {origin}"
    if not isinstance(metadata.get("esp_mb"), int) or metadata["esp_mb"] > ESP_LIMIT_MB:
        return f"its ESP is {metadata.get('esp_mb')} MiB, over the {ESP_LIMIT_MB} MiB limit"
    return ""


def checksum_line(path: Path) -> str:
    """The line `sha256sum NAME` prints, so `sha256sum -c` accepts the file."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return f"{digest.hexdigest()}  {path.name}\n"


def human_size(size: int) -> str:
    return f"{size / (1 << 30):.2f} GiB"


def rclone_environment(environment: dict[str, str]) -> dict[str, str] | None:
    """rclone's settings for the R2 remote, or None without credentials."""
    key, secret, endpoint = (environment.get(name, "") for name in ("R2_ACCESS_KEY", "R2_SECRET_KEY", "R2_ENDPOINT"))
    if not (key and secret and endpoint):
        return None
    return {
        **environment,
        "RCLONE_CONFIG_R2_TYPE": "s3",
        "RCLONE_CONFIG_R2_PROVIDER": "Cloudflare",
        "RCLONE_CONFIG_R2_REGION": "auto",
        "RCLONE_CONFIG_R2_ACCESS_KEY_ID": key,
        "RCLONE_CONFIG_R2_SECRET_ACCESS_KEY": secret,
        "RCLONE_CONFIG_R2_ENDPOINT": endpoint,
    }


# ── Talking to the runner ─────────────────────────────────────────────────

class StepFailed(Exception):
    """A step's check failed; the message is the annotation."""


def run(command: list[str], **options) -> subprocess.CompletedProcess:
    print("+", " ".join(command), flush=True)
    return subprocess.run(command, check=True, **options)


def append(variable: str, line: str) -> None:
    target = os.environ.get(variable)
    if target:
        with open(target, "a", encoding="utf-8") as stream:
            stream.write(line + "\n")
    else:
        print(f"{variable}: {line}")


def output(name: str, value: str) -> None:
    append("GITHUB_OUTPUT", f"{name}={value}")


def summary(line: str) -> None:
    append("GITHUB_STEP_SUMMARY", line)


def runner_temp() -> Path:
    return Path(os.environ.get("RUNNER_TEMP", "/tmp"))


def missing(tools: dict[str, str]) -> list[str]:
    """The packages whose marker file is not on this runner."""
    return [package for package, marker in tools.items() if not Path(marker).exists()]


def install(packages: list[str]) -> None:
    if not packages:
        return
    run(["sudo", "apt-get", "update", "-qq"])
    run(["sudo", "apt-get", "install", "-y", "-qq", *packages])


def smoke_boot(image: Path, media: str, log: Path) -> None:
    log.parent.mkdir(parents=True, exist_ok=True)
    run([sys.executable, str(ROOT / "scripts/iso_smoke_boot.py"), str(image), "--media", media, "--log", str(log)])


# ── Commands ──────────────────────────────────────────────────────────────

def unconfine_lsblk() -> None:
    """Let the image's lsblk read loop devices on an Ubuntu runner.

    Ubuntu attaches an AppArmor profile to /usr/bin/lsblk by path, so it also
    confines the lsblk of a container, and it denies reading /dev/loop*.
    `bootc install to-disk --via-loopback` asks lsblk for the type of the
    partitions it made on a loop device; denied, lsblk reports none and the
    install stops with "root partition 3 has type <none>".
    """
    if not LSBLK_PROFILE.exists():
        return
    result = subprocess.run(["sudo", "apparmor_parser", "--remove", str(LSBLK_PROFILE)],
                            capture_output=True, text=True)
    # Not loaded is as good as removed.
    if result.returncode != 0:
        print(f"apparmor_parser: {result.stderr.strip()}")


def prepare(args: argparse.Namespace) -> None:
    install(missing(TOOLS))
    unconfine_lsblk()
    if not Path("/dev/kvm").exists():
        raise StepFailed("no /dev/kvm on this runner; the boot tests need it")
    run(["sudo", "chmod", "666", "/dev/kvm"])
    token, actor = os.environ.get("GH_TOKEN", ""), os.environ.get("GH_ACTOR", "")
    if not (token and actor):
        raise StepFailed("GH_TOKEN and GH_ACTOR are needed to read the pushed images")
    # skopeo reads the image for the ISO as this user, podman pulls it for
    # the disk install as root; each keeps its own login. The runner has no
    # user runtime directory for skopeo's default credentials file, so the
    # login goes to a file of this job and later steps are pointed at it.
    credentials = runner_temp() / "registry-auth.json"
    login = ["login", "ghcr.io", "--username", actor, "--password-stdin"]
    run(["skopeo", *login, "--authfile", str(credentials)], input=token, text=True)
    append("GITHUB_ENV", f"REGISTRY_AUTH_FILE={credentials}")
    run(["sudo", "podman", *login], input=token, text=True)


def resolve(args: argparse.Namespace) -> None:
    reference = f"{args.image}:{args.tag}"
    inspect = json.loads(run(["skopeo", "inspect", "--no-tags", f"docker://{reference}"],
                             capture_output=True, text=True).stdout)
    problem = image_problem(inspect, args.head_sha)
    if problem:
        raise StepFailed(f"{reference} cannot be tested: {problem}")
    output("digest", inspect["Digest"])
    print(f"Testing {args.image}@{inspect['Digest']}")


def boot_disk(args: argparse.Namespace) -> None:
    """Install the image the way a machine gets it, then boot that disk."""
    pinned = f"{args.image}@{args.digest}"
    name = args.image.rsplit("/", 1)[-1]
    # `just generate-bootable-image` installs <name>:latest from root's
    # podman storage; the variant picks the name.
    variant = "nvidia" if name.endswith("-nvidia") else "default"
    local = f"localhost/{name}:latest"
    work = runner_temp()
    disk = work / "bootable.raw"
    try:
        run(["sudo", "podman", "pull", "--quiet", pinned])
        run(["sudo", "podman", "tag", pinned, local])
        run(["just", "generate-bootable-image", variant], cwd=ROOT, env={**os.environ, "BUILD_BASE_DIR": str(work)})
        run(["sudo", "chown", f"{os.getuid()}:{os.getgid()}", str(disk)])
        smoke_boot(disk, "disk", args.logs / f"{name}-disk.log")
    finally:
        # The disk and the image are tens of GB the ISO build needs back.
        disk.unlink(missing_ok=True)
        subprocess.run(["sudo", "podman", "rmi", "-f", local, pinned], check=False, capture_output=True)
    summary(f"- `{args.image}:{args.tag}` boots from an installed disk")


def iso_changed_command(args: argparse.Namespace) -> None:
    # The checkout is the pull request's merge commit; its first parent is
    # the base branch, so this diff is exactly what the pull request changes.
    run(["git", "fetch", "--quiet", "--no-tags", "--depth=2", "origin", os.environ.get("GITHUB_SHA", "HEAD")], cwd=ROOT)
    names = run(["git", "diff", "--name-only", "HEAD^1", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.split("\n")
    if iso_changed(names):
        output("changed", "true")
        print("This pull request changes the live ISO.")
    else:
        print("No live ISO changes in this pull request; not building an ISO.")


def build_iso(args: argparse.Namespace) -> None:
    origin = f"{args.image}:{args.tag}"
    name = iso_name(args.image, args.tag)
    built = ROOT / ".build-iso"
    # The installed system records this digest and follows :pr-N.
    run([sys.executable, str(ROOT / "scripts/live_iso.py"), f"docker://{args.image}@{args.digest}", origin])
    args.logs.mkdir(parents=True, exist_ok=True)
    shutil.copy(built / "dakota-live.json", args.logs / f"{name}.json")
    problem = metadata_problem(json.loads((built / "dakota-live.json").read_text()), args.digest, origin)
    if problem:
        raise StepFailed(f"{name} does not describe the pushed image: {problem}")
    args.out.mkdir(parents=True, exist_ok=True)
    iso = args.out / name
    shutil.move(built / "dakota-live.iso", iso)
    shutil.rmtree(built)
    smoke_boot(iso, "usb", args.logs / f"{name}-usb.log")
    output("iso", str(iso))


def upload_iso(args: argparse.Namespace) -> None:
    environment = rclone_environment(dict(os.environ))
    if environment is None:
        raise StepFailed("R2 credentials are not configured; the ISO was built but not uploaded")
    iso: Path = args.iso
    checksum = iso.with_name(iso.name + "-CHECKSUM")
    line = checksum_line(iso)
    checksum.write_text(line)
    # The checksum goes first, so a visible ISO always has one.
    for path in (checksum, iso):
        run(["rclone", "copyto", "--log-level", "INFO", "--s3-no-check-bucket", str(path), f"{R2_BUCKET}/{path.name}"],
            env=environment)
    summary(f"- [{iso.name}]({PUBLIC_URL}/{iso.name}) ({human_size(iso.stat().st_size)}), sha256 `{line.split()[0]}`")


def delete_isos(args: argparse.Namespace) -> None:
    environment = rclone_environment(dict(os.environ))
    if environment is None:
        print("R2 credentials are not configured; nothing to delete")
        return
    install(missing({"rclone": TOOLS["rclone"]}))
    present = set(run(["rclone", "lsf", R2_BUCKET, "--files-only"], env=environment,
                      capture_output=True, text=True).stdout.split("\n"))
    # Exact names only: this bucket also holds the release ISOs.
    for name in iso_objects(args.images, args.tag):
        if name in present:
            run(["rclone", "deletefile", "--log-level", "INFO", "--s3-no-check-bucket", f"{R2_BUCKET}/{name}"],
                env=environment)


def parser() -> argparse.ArgumentParser:
    top = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = top.add_subparsers(dest="command", required=True)

    def command(name: str, function, *options: str) -> None:
        sub = commands.add_parser(name)
        sub.set_defaults(function=function)
        for option in options:
            if option in ("--logs", "--out", "--iso"):
                sub.add_argument(option, type=Path, required=True)
            elif option == "--images":
                sub.add_argument(option, nargs="+", required=True)
            else:
                sub.add_argument(option, required=True)

    command("prepare", prepare)
    command("resolve", resolve, "--image", "--tag", "--head-sha")
    command("boot-disk", boot_disk, "--image", "--tag", "--digest", "--logs")
    command("iso-changed", iso_changed_command)
    command("build-iso", build_iso, "--image", "--tag", "--digest", "--logs", "--out")
    command("upload-iso", upload_iso, "--iso")
    command("delete-isos", delete_isos, "--tag", "--images")
    return top


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        args.function(args)
    except StepFailed as failure:
        print(f"::error::{failure}")
        return 1
    except subprocess.CalledProcessError as error:
        print(f"::error::{error.cmd[0]} exited with {error.returncode} during {args.command}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
