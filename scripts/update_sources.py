#!/usr/bin/env python3
"""Update CI-managed source pins for x86_64, without committing or publishing."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
from dataclasses import dataclass
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CORE = "core-junctions"
# Overridden into gnome-build-meta, so it must provide every plugin GBM's
# project.conf loads: copy GBM's pin rather than tracking it independently.
PLUGINS_COMMUNITY = "elements/plugins/buildstream-plugins-community.bst"
TAILSCALE_FEED = "https://pkgs.tailscale.com/stable/?mode=json"

# This is also CI's matrix. Keep review notes with the corresponding element.
TRACKED = [
    ("bluefin/brew.bst", "brew", ""),
    ("bluefin/common.bst", "common", ""),
    ("bluefin/jetbrains-mono.bst", "jetbrains-mono", ""),
    ("bluefin/shell-extensions/app-indicators.bst", "app-indicators extension", ""),
    ("bluefin/shell-extensions/blur-my-shell.bst", "blur-my-shell extension", ""),
    ("bluefin/shell-extensions/dash-to-dock.bst", "dash-to-dock extension", ""),
    ("bluefin/shell-extensions/gsconnect.bst", "gsconnect extension", ""),
    ("bluefin/shell-extensions/custom-command-menu.bst", "custom-command-menu extension", ""),
    ("bluefin/efibootmgr.bst", "efibootmgr", ""),
    ("bluefin/shell-extensions/caffeine.bst", "caffeine extension", ""),
    ("bluefin/distrobox.bst", "distrobox", ""),
    ("bluefin/xdg-terminal-exec.bst", "xdg-terminal-exec", ""),
    ("bluefin/nautilus-python.bst", "nautilus-python", ""),
    ("gnomeos-deps/bootc.bst", "bootc", "review: core system component"),
    ("core/dnsmasq.bst", "dnsmasq", "review: core system component"),
    ("bluefin/sudo-rs.bst", "sudo-rs", "review: core system component"),
    ("bluefin/uutils-coreutils.bst", "uutils-coreutils", "review: core system component"),
    # No release tags: every update is unreleased code.
    ("bluefin/shell-extensions/gradia-capture.bst", "gradia-capture extension",
     "review: unreleased branch head"),
    # Despite its name this is a docker source, not a release tarball.
    ("bluefin/brew-tarball.bst", "brew-tarball", ""),
    ("bluefin/wallpapers.bst", "wallpapers", ""),
    # Same git source and track pattern as core/linux-fdsdk.bst, so both move
    # to the same stable tag on the same run.
    ("bluefin/hyperv-daemons.bst", "Hyper-V daemons",
     "review: tools/hv from the core/linux-fdsdk.bst tree"),
]


# Kernel refs are owned independently by testing and next. Respect each
# checkout's track patterns; never widen a stable series or force next to stable.
KERNELS = [
    ("core/linux-fdsdk.bst", "Linux kernel",
     "review: kernel patches, vendored FDSDK helpers, and NVIDIA build"),
    ("core/linux-ogc.bst", "OGC kernel",
     "review: OGC patches and gaming NVIDIA build"),
]


@dataclass(frozen=True)
class Release:
    repo: str
    pattern: str
    replacement: str
    x86_asset_suffix: str = ""
    query: str = ".tag_name"
    endpoint: str = "releases/latest"
    tag_pattern: str = r"v[0-9]+\.[0-9]+\.[0-9]+"
    # Pins the release together with sources derived from it, in place of a
    # URL rewrite; called with the version (tag without "v").
    generator: str = ""


RELEASES = {
    "bluefin/gum.bst": Release(
        "charmbracelet/gum", r"download/(?P<version>v[0-9.]+)/gum_[0-9.]+_",
        "download/{tag}/gum_{version}_", x86_asset_suffix="_Linux_x86_64.tar.gz"),
    "bluefin/gtk4-layer-shell.bst": Release(
        "wmww/gtk4-layer-shell", r"tags/(?P<version>v[0-9.]+)\.tar\.gz",
        "tags/{tag}.tar.gz"),
    "bluefin/tailscale.bst": Release(
        "tailscale/tailscale", r"tailscale_(?P<version>[0-9.]+)_",
        "tailscale_{version}_", x86_asset_suffix="_amd64.tgz"),
    "bluefin/uupd.bst": Release(
        "ublue-os/uupd", r"download/(?P<version>v[^/]+)/", "download/{tag}/",
        x86_asset_suffix="_Linux_x86_64.tar.gz"),
    "bluefin/jetbrains-mono-nerd-font.bst": Release(
        "ryanoasis/nerd-fonts", r"download/(?P<version>v[^/]+)/", "download/{tag}/"),
    # Published weekly as immutable YY.MM.N releases.
    "bluefin/bluefin-docs.bst": Release(
        "projectbluefin/documentation",
        r"download/(?P<version>[0-9]{2}\.[0-9]{2}\.[0-9]+)/bluefin\.pdf",
        "download/{tag}/bluefin.pdf", tag_pattern=r"[0-9]{2}\.[0-9]{2}\.[0-9]+"),
    # No versioned GitHub releases (only a rolling "tip"), so read tags. Each
    # release changes the Zig dependency graph, which the generator re-pins.
    "bluefin/ghostty.bst": Release(
        "ghostty-org/ghostty", r"ghostty_releases:(?P<version>[0-9.]+)/", "",
        endpoint="tags?per_page=100",
        query='[.[].name | select(test("^v[0-9]+\\\\.[0-9]+\\\\.[0-9]+$"))]'
              ' | sort_by(ltrimstr("v") | split(".") | map(tonumber)) | last',
        generator="files/scripts/generate_ghostty_sources.py"),
}


def matrix() -> dict:
    return {"include": [dict(element=element, title=f"chore(deps): update {title}", note=note)
                        for element, title, note in TRACKED + KERNELS]}


def run(*args: str, capture: bool = False) -> str:
    result = subprocess.run(args, cwd=ROOT, check=True, text=True,
                            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE if capture else None)
    return result.stdout.strip() if capture else ""


def track(element: str) -> None:
    run("just", "bst", "--no-interactive", "-o", "arch", "x86_64",
        "source", "track", element)


@contextmanager
def rollback_on_failure(paths: list[Path]):
    """Restore pre-invocation contents (including local edits), not Git HEAD."""
    with tempfile.TemporaryDirectory(prefix="dakota-source-update-") as tmp:
        backups = []
        for index, path in enumerate(paths):
            backup = Path(tmp) / str(index)
            if path.is_dir():
                shutil.copytree(path, backup)
            elif path.exists():
                shutil.copy2(path, backup)
            backups.append((path, backup))
        try:
            yield
        except BaseException:
            for path, backup in backups:
                if path.is_dir():
                    shutil.rmtree(path)
                elif path.exists():
                    path.unlink()
                if backup.is_dir():
                    shutil.copytree(backup, path)
                elif backup.exists():
                    shutil.copy2(backup, path)
            raise


def rewrite_release(text: str, release: Release, tag: str) -> tuple[str, str]:
    if not re.fullmatch(release.tag_pattern, tag):
        raise ValueError(f"Unexpected release tag for {release.repo}: {tag!r}")
    versions = []
    count = 0
    replacement = release.replacement.format(tag=tag, version=tag.removeprefix("v"))

    def replace_url(match):
        nonlocal count
        url = match.group(2)
        # ARM is paused: preserve its URL as well as its checksum. Only the
        # selected x86_64 asset (or an architecture-independent URL) advances.
        if release.x86_asset_suffix and not url.endswith(release.x86_asset_suffix):
            return match.group(0)
        found = list(re.finditer(release.pattern, url))
        if len(found) != 1:
            raise ValueError(f"Expected one release version in URL: {url}")
        versions.extend(m.group("version") for m in found)
        count += 1
        return match.group(1) + re.sub(release.pattern, lambda _: replacement, url)

    # Change source URLs only, never comments, refs, or install commands.
    updated = re.sub(r"^(\s*url:\s+)(\S+)", replace_url, text, flags=re.MULTILINE)
    if count != 1:
        raise ValueError(f"Expected one selected source URL for {release.repo}, found {count}")
    return updated, ", ".join(dict.fromkeys(versions))


def tailscale_release_tag(payload: str) -> str:
    """Use the published Linux archive, not a potentially platform-only Git tag."""
    feed = json.loads(payload)
    tarballs = feed.get("Tarballs") if isinstance(feed, dict) else None
    filename = tarballs.get("amd64") if isinstance(tarballs, dict) else None
    match = (re.fullmatch(r"tailscale_([0-9]+\.[0-9]+\.[0-9]+)_amd64\.tgz", filename)
             if isinstance(filename, str) else None)
    if not match:
        raise ValueError("Tailscale package feed has no valid Tarballs.amd64 archive")
    # Strict filename validation ensures rewrite_release reconstructs precisely
    # this asset on the existing package host, never a feed-supplied URL/host.
    return f"v{match[1]}"


def update_release(element: str, out: Path | None) -> None:
    release = RELEASES[element]
    if element == "bluefin/tailscale.bst":
        tag = tailscale_release_tag(run("curl", "-fsSL", TAILSCALE_FEED, capture=True))
    else:
        tag = run("gh", "api", f"repos/{release.repo}/{release.endpoint}",
                  "--jq", release.query, capture=True)
    path = ROOT / "elements" / element
    original = path.read_text()
    if release.generator:
        if not re.fullmatch(release.tag_pattern, tag):
            raise ValueError(f"Unexpected release tag for {release.repo}: {tag!r}")
        old = re.search(release.pattern, original)["version"]
        if old == tag.removeprefix("v"):
            print(f"{element}: already up to date")
            return
        run(sys.executable, release.generator, tag.removeprefix("v"))
    else:
        updated, old = rewrite_release(original, release, tag)
        if updated == original:
            print(f"{element}: already up to date")
            return
        path.write_text(updated)
        track(element)
    if out is not None:
        slug = Path(element).stem
        # Report versions in the element's own style (with or without "v").
        new = tag if old.startswith("v") else tag.removeprefix("v")
        links = f"[release](https://github.com/{release.repo}/releases/tag/{tag})"
        if ", " not in old:
            old_tag = ("v" if tag.startswith("v") else "") + old.removeprefix("v")
            links += f" · [compare](https://github.com/{release.repo}/compare/{old_tag}...{tag})"
        run(sys.executable, ".github/scripts/track_bundle.py", "record",
            "--out", str(out), "--slug", slug,
            "--title", f"chore(deps): update {slug} {old} -> {new}",
            "--change", f"`{old}` → `{new}`", "--links", links,
            f"elements/{element}")


def sync_ogc_localversion(text: str) -> str:
    """Derive the module-release suffix from the tag, including next's RC tags."""
    refs = re.findall(r"^  ref: (\S+)$", text, re.MULTILINE)
    match = (re.fullmatch(r"v[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-rc[0-9]+)?"
                         r"(-ogc[0-9]+)(?:-[0-9]+-g[0-9a-f]{40})?", refs[0])
             if len(refs) == 1 else None)
    if not match:
        raise ValueError("Cannot derive ogc-localversion from the tracked OGC release tag")
    updated, count = re.subn(r"^  ogc-localversion:.*$",
                            lambda _: f"  ogc-localversion: '{match[1]}'", text,
                            flags=re.MULTILINE)
    if count != 1:
        raise ValueError("Expected exactly one ogc-localversion variable")
    return updated


def gbm_file(sha: str, path: str) -> str:
    quoted = path.replace("/", "%2F")
    url = ("https://gitlab.gnome.org/api/v4/projects/GNOME%2Fgnome-build-meta/"
           f"repository/files/{quoted}/raw?ref={sha}")
    return run("curl", "-fsSL", url, capture=True)


def sync_plugins_community(upstream: str) -> None:
    source = re.search(r"^- kind: tar\n  url: (pypi:[A-Za-z0-9/._-]+\.tar\.gz)\n"
                       r"  ref: ([0-9a-f]{64})$", upstream, re.MULTILINE)
    if not source:
        raise ValueError("Could not read buildstream-plugins-community pin from GNOME Build Meta")
    path = ROOT / PLUGINS_COMMUNITY
    text, count = re.subn(r"^(  url: )pypi:\S+\n(  ref: )\S+$",
                          lambda m: f"{m[1]}{source[1]}\n{m[2]}{source[2]}",
                          path.read_text(), count=1, flags=re.MULTILINE)
    if count != 1:
        raise ValueError("Missing local buildstream-plugins-community tar source")
    path.write_text(text)


def update_core() -> None:
    track("gnome-build-meta.bst")
    gbm = (ROOT / "elements/gnome-build-meta.bst").read_text()
    ref = re.search(r"^\s*ref: (\S+)", gbm, re.MULTILINE)
    sha = re.search(r"-g([0-9a-f]{40})$", ref[1]) if ref else None
    if not sha:
        raise ValueError("Could not extract GNOME Build Meta commit SHA")
    upstream = gbm_file(sha[1], "elements/freedesktop-sdk.bst")
    # Read the ref from the git source, not another source or config block.
    source = re.search(r"^  url: gitlab:freedesktop-sdk/[^\n]+\n"
                       r"(?:(?!^\S)[^\n]*\n)*?^  ref: (\S+)", upstream, re.MULTILINE)
    if not source or not re.fullmatch(r"[A-Za-z0-9._-]+", source[1]):
        raise ValueError("Could not read freedesktop-sdk pin from GNOME Build Meta")
    path = ROOT / "elements/freedesktop-sdk.bst"
    text, count = re.subn(r"^(\s*)ref:.*$", lambda m: f"{m[1]}ref: {source[1]}",
                          path.read_text(), count=1, flags=re.MULTILINE)
    if count != 1:
        raise ValueError("Missing local freedesktop-sdk ref")
    if path.read_text() != text:
        print("REVIEW: FDSDK changed. Compare core/linux-fdsdk.bst, patches/linux, "
              "files/linux/config-utils.sh and files/linux/fdsdk-config.sh with the new SDK; "
              "preserve Dakota's local kernel configuration.")
    path.write_text(text)
    sync_plugins_community(gbm_file(sha[1], "elements/plugins/buildstream-plugins-community.bst"))
    run("just", "patch-sync")
    run("just", "patch-drift-check")


def update(element: str, out: Path | None) -> None:
    paths = [ROOT / "elements" / element]
    if element == CORE:
        paths = [ROOT / p for p in ("elements/gnome-build-meta.bst",
                 "elements/freedesktop-sdk.bst", PLUGINS_COMMUNITY, "patches/freedesktop-sdk",
                 "patches/freedesktop-sdk.manifest.json")]
    with rollback_on_failure(paths):
        if element == CORE:
            update_core()
        elif element in RELEASES:
            update_release(element, out)
        else:
            track(element)
            if element == "core/linux-ogc.bst":
                path = paths[0]
                path.write_text(sync_ogc_localversion(path.read_text()))
            if element in {item[0] for item in KERNELS}:
                # Tracking a git ref does not apply subsequent patch_queue
                # sources. Fetch the complete element before accepting the pin,
                # inside the rollback boundary and before recording it for CI.
                print(f"Checking kernel sources and patches: {element}", flush=True)
                run("just", "bst", "--no-interactive", "-o", "arch", "x86_64",
                    "source", "fetch", "--deps", "none", element)
                print(f"REVIEW: {element}: sources fetched; build the kernel "
                      "and corresponding NVIDIA drivers before shipping.")
            if out is not None:
                item = next(item for item in matrix()["include"] if item["element"] == element)
                run(sys.executable, ".github/scripts/track_bundle.py", "record-element",
                    "--element", element, "--title", item["title"], "--note", item["note"],
                    "--out", str(out))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    select = parser.add_mutually_exclusive_group()
    select.add_argument("--group", choices=("all", "bundle", "tracked", "tarballs", "kernels", CORE),
                        default="all", help="update subset (default: all)")
    select.add_argument("--element", choices=[item[0] for item in TRACKED + KERNELS] + list(RELEASES),
                        metavar="ELEMENT", help="one CI-managed element; use --list to see the scope")
    parser.add_argument("--list", action="store_true", help="list selected updates without network or writes")
    parser.add_argument("--matrix", action="store_true", help="print the CI tracking matrix as JSON")
    parser.add_argument("--record-dir", type=Path, help="CI only: record successful bundle updates here")
    args = parser.parse_args(argv)
    if args.matrix:
        print(json.dumps(matrix()))
        return 0
    selected = []
    if args.element:
        selected = [args.element]
    else:
        if args.group in ("all", "bundle", "tracked"):
            selected.extend(item[0] for item in TRACKED + KERNELS)
        if args.group == "kernels":
            selected.extend(item[0] for item in KERNELS)
        if args.group in ("all", "bundle", "tarballs"):
            selected.extend(RELEASES)
        if args.group in ("all", CORE):
            selected.append(CORE)
    if args.list:
        print("\n".join(selected))
        return 0
    failed = []
    out = args.record_dir.resolve() if args.record_dir else None
    for element in selected:
        print(f"Updating {element}", flush=True)
        try:
            update(element, out)
        except (OSError, ValueError, subprocess.CalledProcessError) as exc:
            print(f"FAILED {element}: {exc}", file=sys.stderr)
            failed.append(element)
    if failed:
        print("Failed updates (restored to their starting contents): " + ", ".join(failed),
              file=sys.stderr)
        return 1
    print("Source update pass complete. Review git diff, then run just validate.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
