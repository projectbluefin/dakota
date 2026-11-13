"""Offline coverage for the shared local/CI source updater."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest import mock

from scripts import update_sources as updater

REPOSITORY = Path(__file__).resolve().parents[1]
SHA = "b" * 40


class SelectionTests(unittest.TestCase):
    def select(self, *args):
        with mock.patch.object(updater, "update") as update, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(updater.main(list(args)), 0)
        return [c.args[0] for c in update.call_args_list]

    def test_default_is_full_ci_scope(self):
        expected = [x[0] for x in updater.TRACKED + updater.KERNELS] + list(updater.RELEASES) + [updater.CORE]
        self.assertEqual(self.select(), expected)
        self.assertEqual(len(expected), len(set(expected)))

    def test_groups_and_element(self):
        self.assertEqual(self.select("--group", "bundle"), self.select()[:-1])
        self.assertEqual(self.select("--group", "tracked"), [x[0] for x in updater.TRACKED + updater.KERNELS])
        self.assertEqual(self.select("--group", "kernels"), [x[0] for x in updater.KERNELS])
        self.assertEqual(self.select("--element", "core/linux-ogc.bst"), ["core/linux-ogc.bst"])
        self.assertEqual(self.select("--group", "tarballs"), list(updater.RELEASES))
        self.assertEqual(self.select("--group", "core-junctions"), [updater.CORE])
        self.assertEqual(self.select("--element", "bluefin/gum.bst"), ["bluefin/gum.bst"])

    def test_unknown_element_and_conflicting_selection_fail_before_work(self):
        with mock.patch.object(updater, "update") as update, \
                contextlib.redirect_stderr(io.StringIO()):
            for args in (["--element", "../../oops"],
                         ["--group", "bundle", "--element", "bluefin/gum.bst"]):
                with self.assertRaises(SystemExit):
                    updater.main(args)
            update.assert_not_called()

    def test_list_and_matrix_are_offline(self):
        with mock.patch.object(updater, "run") as run, \
                mock.patch.object(updater, "update") as update:
            for args in (["--list"], ["--matrix"]):
                out = io.StringIO()
                with contextlib.redirect_stdout(out):
                    self.assertEqual(updater.main(args), 0)
                if args == ["--matrix"]:
                    self.assertEqual(json.loads(out.getvalue()), updater.matrix())
            run.assert_not_called()
            update.assert_not_called()

    def test_failure_continues_and_returns_nonzero(self):
        with mock.patch.object(updater, "update", side_effect=[ValueError("broken")] +
                               [None] * (len(updater.RELEASES) - 1)) as update, \
                contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(io.StringIO()) as err:
            self.assertEqual(updater.main(["--group", "tarballs"]), 1)
        self.assertEqual(update.call_count, len(updater.RELEASES))
        first_element = next(iter(updater.RELEASES))
        self.assertIn(first_element, err.getvalue())

    def test_matrix_preserves_review_notes_and_adds_oci_source(self):
        items = {x["element"]: x for x in updater.matrix()["include"]}
        self.assertEqual(len(items), len(updater.TRACKED) + len(updater.KERNELS))
        for kernel, _, _ in updater.KERNELS:
            self.assertIn("NVIDIA build", items[kernel]["note"])
        self.assertIn("bluefin/brew-tarball.bst", items)
        self.assertIn("bluefin/wallpapers.bst", items)
        self.assertEqual(items["bluefin/shell-extensions/gradia-capture.bst"]["note"],
                         "review: unreleased branch head")
        for element in items:
            self.assertTrue((REPOSITORY / "elements" / element).is_file())

    def test_every_network_source_has_an_updater_or_a_pin_reason(self):
        # Every source kind is a network source unless it is local content
        # or a dependency list that moves with the element owning it, so a
        # kind nobody listed here still needs an updater.
        network = re.compile(r"^\s*- kind:\s*(?!(?:local|patch|patch_queue|cargo2|registry|go_module"
                             r"|gen_cargo_lock)\s*$)\S+\s*$", re.MULTILINE)
        updated = ({x[0] for x in updater.TRACKED + updater.KERNELS} | set(updater.RELEASES)
                   | {"gnome-build-meta.bst", "freedesktop-sdk.bst",
                      "plugins/buildstream-plugins-community.bst"})
        self.assertFalse(updated & set(updater.DERIVED), "element is both updated and derived")
        for element, owner in updater.DERIVED.items():
            self.assertTrue(owner == updater.CORE or element in updater.RELEASES[owner].derived,
                            f"{owner} does not move {element}")
        updated |= set(updater.DERIVED)
        self.assertFalse(updated & set(updater.PINNED), "element is both updated and pinned")
        unclassified = []
        for path in sorted((REPOSITORY / "elements").rglob("*.bst")):
            element = str(path.relative_to(REPOSITORY / "elements"))
            if network.search(path.read_text()) and element not in updated | set(updater.PINNED):
                unclassified.append(element)
        self.assertEqual(unclassified, [], "add each element to TRACKED or RELEASES, "
                         "or to PINNED with the reason it cannot be updated")
        for element, reason in updater.PINNED.items():
            self.assertTrue((REPOSITORY / "elements" / element).is_file(), element)
            self.assertTrue(reason.strip(), element)

    def test_hyperv_daemons_tracks_the_kernel_source(self):
        # Hyper-V daemons build from the kernel's tools/hv. Sharing url, track
        # and exclude with the kernel moves both to the same tag on each run.
        def git_source(element):
            text = (REPOSITORY / "elements" / element).read_text()
            block = re.search(r"^- kind: git_repo\n((?:  [^\n]*\n)+)", text, re.MULTILINE)
            self.assertIsNotNone(block, element)
            lines = [line for line in block[1].splitlines()
                     if not line.lstrip().startswith("#")]
            return [line for line in lines if not line.startswith("  ref:")]
        self.assertEqual(git_source("bluefin/hyperv-daemons.bst"),
                         git_source("core/linux-fdsdk.bst"))


    def test_ogc_kernel_follows_the_stable_kernel_series(self):
        # Gaming images must not stay a kernel series behind the others.
        def series(element, suffix):
            text = (REPOSITORY / "elements" / element).read_text()
            return re.search(rf"^  track: v([0-9]+\.[0-9]+){suffix}$", text, re.MULTILINE)[1]
        self.assertEqual(series("core/linux-ogc.bst", r"\.\*-ogc\*"),
                         series("core/linux-fdsdk.bst", r"\*"))


# A tag and asset name each release's patterns accept, newer than any pin.
SAMPLE_TAGS = ("v99.88.77", "99.88.77", "stable-99.88.77", "a" * 40, "99999", "999.88.77",
               "2.24.99-9+deb12u9", "99.88.77.66")
SAMPLE_ASSETS = ("open-vm-tools-99.88.77-12345.tar.gz", "MangoHud-99.88.77.r0.gabcdef0.tar.gz")


def sample(release):
    tag = next(t for t in SAMPLE_TAGS if re.fullmatch(release.tag_pattern, t))
    asset = next((a for a in SAMPLE_ASSETS if re.fullmatch(release.asset, a)), "") if release.asset else ""
    return tag, asset


class RewriteTests(unittest.TestCase):
    def test_every_release_updates_only_urls_and_is_idempotent(self):
        for element, release in updater.RELEASES.items():
            if release.generator:
                continue
            with self.subTest(element=element):
                original = (REPOSITORY / "elements" / element).read_text()
                tag, asset = sample(release)
                updated, old = updater.rewrite_release(original, release, tag, asset)
                self.assertNotEqual(updated, original)
                self.assertTrue(old)
                self.assertEqual(updater.pinned_version(original, release), old.split(", ")[0])
                keys = ("url:",) + tuple(f"{key}:" for key in release.keys)
                unchanged = lambda text: [line for line in text.splitlines()
                                           if not line.lstrip().startswith(keys)]
                self.assertEqual(unchanged(updated), unchanged(original))
                self.assertEqual(updater.rewrite_release(updated, release, tag, asset)[0], updated)

    def test_repeated_version_keys_move_with_the_url(self):
        release = updater.RELEASES["bluefin-nvidia/nvidia-drivers.bst"]
        text = (REPOSITORY / "elements/bluefin-nvidia/nvidia-drivers.bst").read_text()
        old = updater.pinned_version(text, release)
        updated, _ = updater.rewrite_release(text, release, "999.88.77")
        self.assertIn("Linux-x86_64/999.88.77/NVIDIA-Linux-x86_64-999.88.77.run", updated)
        self.assertIn("filename: NVIDIA-Linux-x86_64-999.88.77.run", updated)
        self.assertIn("nvidia-version: '999.88.77'", updated)
        self.assertNotIn(old, re.sub(r"(?m)^\s*#.*$", "", updated))

    def test_multi_asset_release_moves_together_and_skips_paused_arm(self):
        release = updater.RELEASES["bluefin/tealdeer.bst"]
        text = (REPOSITORY / "elements/bluefin/tealdeer.bst").read_text()
        old = updater.pinned_version(text, release)
        updated, _ = updater.rewrite_release(text, release, "v99.88.77")
        self.assertEqual(updated.count("download/v99.88.77/"), 4)
        self.assertIn(f"download/{old}/tealdeer-linux-aarch64-musl", updated)
        fonts = updater.RELEASES["bluefin/nerd-fonts-symbols.bst"]
        text = (REPOSITORY / "elements/bluefin/nerd-fonts-symbols.bst").read_text()
        self.assertEqual(updater.rewrite_release(text, fonts, "v99.88.77")[0].count("/v99.88.77/"), 4)

    def test_asset_names_are_validated(self):
        release = updater.RELEASES["bluefin/open-vm-tools.bst"]
        text = (REPOSITORY / "elements/bluefin/open-vm-tools.bst").read_text()
        for asset in ("", "open-vm-tools-1.2.3-4.tar.gz/../evil", "other-1.2.3-4.tar.gz"):
            with self.subTest(asset=asset), self.assertRaises(ValueError):
                updater.rewrite_release(text, release, "stable-1.2.3", asset)

    def test_older_arm_version_is_left_alone(self):
        release = updater.RELEASES["bluefin/gum.bst"]
        text = (REPOSITORY / "elements/bluefin/gum.bst").read_text()
        urls = re.findall(r"url: (\S+)", text)
        mixed = text.replace(urls[1], "github_files:charmbracelet/gum/releases/download/"
                             "v0.1.0/gum_0.1.0_Linux_arm64.tar.gz")
        updated, old = updater.rewrite_release(mixed, release, "v99.88.77")
        self.assertNotIn("v0.1.0", old)
        self.assertEqual(updated.count("download/v99.88.77/gum_99.88.77_"), 1)
        self.assertIn("download/v0.1.0/gum_0.1.0_Linux_arm64.tar.gz", updated)

    def test_every_arch_specific_release_preserves_arm_url_and_ref(self):
        for element, release in updater.RELEASES.items():
            if not release.x86_asset_suffix:
                continue
            with self.subTest(element=element):
                original = (REPOSITORY / "elements" / element).read_text()
                updated, _ = updater.rewrite_release(original, release, "v99.88.77")
                arm_block = re.search(r'(?m)^  - arch == "aarch64":\n(?:^ {4,}[^\n]*\n)+', original)[0]
                self.assertIn(arm_block, updated)
                original_urls = re.findall(r"url: (\S+)", original)
                updated_urls = re.findall(r"url: (\S+)", updated)
                self.assertEqual(sum(a != b for a, b in zip(original_urls, updated_urls)), 1)

    def test_up_to_date_x86_with_older_arm_is_a_noop(self):
        release = updater.RELEASES["bluefin/gum.bst"]
        text = (REPOSITORY / "elements/bluefin/gum.bst").read_text()
        text, _ = updater.rewrite_release(text, release, "v99.88.77")
        updated, old = updater.rewrite_release(text, release, "v99.88.77")
        self.assertEqual(updated, text)
        self.assertEqual(old, "v99.88.77")

    def test_bad_tags_and_changed_url_layout_fail_closed(self):
        release = updater.RELEASES["bluefin/gum.bst"]
        text = (REPOSITORY / "elements/bluefin/gum.bst").read_text()
        for tag in ("", "null", "v1.2.3/evil", "v1.2.3\nref: bad", "v1.2.3-rc1"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                updater.rewrite_release(text, release, tag)
        for text in ("kind: tar\n", "url: github_files:unexpected/file.tar.gz\n"):
            with self.assertRaises(ValueError):
                updater.rewrite_release(text, release, "v1.2.3")


class KernelVersionTests(unittest.TestCase):
    def test_stable_and_rc_tags_derive_ogc_revision(self):
        for tag in ("v7.2.7-ogc2", "v7.3-rc4-ogc3", "v7.3-ogc4"):
            for ref in (tag, f"{tag}-0-g{SHA}"):
                with self.subTest(ref=ref):
                    text = f"variables:\n  ogc-localversion: '-ogc1'\nsources:\n  ref: {ref}\n"
                    updated = updater.sync_ogc_localversion(text)
                    suffix = re.search(r"-ogc[0-9]+", tag)[0]
                    self.assertIn(f"ogc-localversion: '{suffix}'", updated)
                    self.assertIn(f"ref: {ref}", updated)
                    self.assertEqual(updater.sync_ogc_localversion(updated), updated)

    def test_unknown_ref_or_missing_variable_fails_closed(self):
        for ref in (SHA, "master", "v7.3-rc4", "v7.3-ogcX", "v7.3-ogc2-0-g123"):
            with self.subTest(ref=ref), self.assertRaises(ValueError):
                updater.sync_ogc_localversion(f"  ogc-localversion: '-ogc1'\n  ref: {ref}\n")
        for text in ("  ref: v7.3-ogc2\n", "  ogc-localversion: x\n" * 2 + "  ref: v7.3-ogc2\n"):
            with self.assertRaises(ValueError):
                updater.sync_ogc_localversion(text)


class TailscaleFeedTests(unittest.TestCase):
    def test_selects_amd64_archive_not_global_version(self):
        feed = {"Version": "99.0.0", "TarballsVersion": "98.0.0", "Tarballs": {
            "amd64": "tailscale_1.102.4_amd64.tgz", "arm64": "tailscale_97.0.0_arm64.tgz"}}
        self.assertEqual(updater.tailscale_release_tag(json.dumps(feed)), "v1.102.4")

    def test_invalid_feeds_fail_closed(self):
        for feed in (None, [], {}, {"Tarballs": []}, {"Tarballs": {}},
                     {"Tarballs": {"amd64": None}}, {"Tarballs": {"amd64": 123}},
                     {"Tarballs": {"amd64": "tailscale_1.2.3_arm64.tgz"}},
                     {"Tarballs": {"amd64": "https://example.invalid/tailscale_1.2.3_amd64.tgz"}},
                     {"Tarballs": {"amd64": "../tailscale_1.2.3_amd64.tgz"}},
                     {"Tarballs": {"amd64": "tailscale_1.2.3_amd64.tgz\n"}}):
            with self.subTest(feed=feed), self.assertRaises(ValueError):
                updater.tailscale_release_tag(json.dumps(feed))
        with self.assertRaises(ValueError):
            updater.tailscale_release_tag("not JSON")


# Actual CLI subprocesses with recording tools on PATH. No network, Podman,
# host changes, GitHub writes, or source changes in the real checkout.
STUB = r'''import json, os, pathlib, re, sys
args = sys.argv[1:]
name = pathlib.Path(sys.argv[0]).name
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps([name, *args]) + "\n")
# Newer than every pin, in the shape of each feed outside GitHub.
FEEDS = {
    "extensions.gnome.org": '{"version_tag": 99999, "version": 77}',
    # Only the pinned 615 branch qualifies; 999 is another driver branch.
    "download.nvidia.com": "href='615.99.77/' href='999.1.2/' href='615.1.2/'",
    "steampowered.com": "Filename: pool/steam/s/steam/steam-launcher_99.88.77.66_amd64.deb",
    "ftp-master.debian.org": '[{"libgtk2.0-0": {"oldstable": {"2.24.99-9+deb12u9": {}}}}]',
    "alsa-project.org": "alsa-utils-9.8.7.tar.bz2 alsa-utils-9.8.8.tar.bz2 alsa-utils-1.2.14.tar.bz2",
}
ASSETS = {
    "repos/vmware/open-vm-tools/": "stable-99.88.77\nopen-vm-tools-99.88.77-12345.tar.gz\nother.zip",
    "repos/flightlessmango/MangoHud/": "v99.88.77\nMangoHud-99.88.77.r0.gabcdef0.tar.gz\nMangoHud-v99.88.77-Source.tar.xz",
}
if name == "gh":
    assert args[0] == "api" and args[1].startswith("repos/")
    unprefixed = ("repos/projectbluefin/documentation/", "repos/libimobiledevice/ifuse/")
    default = "99.88.77" if args[1].startswith(unprefixed) else "v99.88.77"
    if args[1].endswith("/commits/master"):
        default = "a" * 40
    if ".assets" in args[-1]:
        default = next(v for k, v in ASSETS.items() if args[1].startswith(k))
    print(os.environ.get("RELEASE_TAG", default))
elif name == "curl" and any(k in args[-1] for k in FEEDS):
    if os.environ.get("FAIL_FEED"):
        sys.exit(22)
    print(os.environ.get("FEED_BODY", next(v for k, v in FEEDS.items() if k in args[-1])))
elif name == "curl" and "core-deps%2Fvte.bst" in args[-1]:
    print(os.environ.get("UPSTREAM_VTE", "kind: meson\nsources:\n- kind: tar\n  url: gnome_downloads:vte/99.88/vte-99.88.77.tar.xz\n  ref: " + "a" * 64 + "\nbuild-depends:\n"))
elif name == "curl" and "alsa-lib.bst" in args[-1]:
    assert "ref=" + "c" * 40 in args[-1]
    print(os.environ.get("UPSTREAM_ALSA", "sources:\n- kind: git_repo\n  url: github:alsa-project/alsa-lib.git\n  track: v*.*.*\n  ref: v9.8.7.1-0-g" + "a" * 40))
elif name == "curl" and args[-1] == "https://pkgs.tailscale.com/stable/?mode=json":
    if os.environ.get("FAIL_FEED"):
        sys.exit(22)
    print(os.environ.get("TAILSCALE_FEED", json.dumps({"Tarballs": {
        "amd64": "tailscale_99.88.77_amd64.tgz"}})))
elif name == "curl" and "buildstream-plugins-community" in args[-1]:
    print(os.environ.get("UPSTREAM_PLUGINS", "kind: junction\n\nsources:\n- kind: tar\n  url: pypi:12/34/" + "e" * 60 + "/buildstream_plugins_community-9.9.9.tar.gz\n  ref: " + "f" * 64))
elif name == "curl":
    print(os.environ.get("UPSTREAM_FDSDK", "kind: junction\nsources:\n- kind: git_repo\n  url: gitlab:freedesktop-sdk/freedesktop-sdk.git\n  track: stable\n  ref: sdk-99-0-g" + "c" * 40))
elif name == "just" and args[0] == "bst" and "checkout" in args:
    assert args[:9] == ["bst", "--no-interactive", "-o", "arch", "x86_64",
                        "source", "checkout", "--deps", "none"]
    assert args[9] == "--directory" and args[10].startswith(".source-check/")
    pathlib.Path(args[10]).mkdir(parents=True)
    if os.environ.get("FAIL_CHECKOUT") == args[-1]:
        print("Failed to apply patches", file=sys.stderr)
        sys.exit(1)
elif name == "just" and args[0] == "bst":
    assert "source" in args and "track" in args
    path = pathlib.Path("elements") / args[-1]
    header, text = path.read_text().split("sources:\n", 1)
    if args[-1] == "gnome-build-meta.bst":
        ref = "gnome-99-0-g" + "b" * 40
    elif args[-1] == "core/linux-ogc.bst":
        ref = os.environ.get("OGC_REF", "v7.2.7-ogc2-0-g" + "b" * 40)
    elif args[-1] == "core/linux-fdsdk.bst":
        ref = os.environ.get("KERNEL_REF", "v7.2.7-0-g" + "b" * 40)
    else:
        ref = "d" * 64
    assert args[args.index("arch") + 1] == "x86_64"
    def repin(text):
        return re.sub(r"(?m)^(\s*ref: ).*$", lambda m: m[1] + ref, text)
    # Simulate BuildStream's architecture selection, including partial writes
    # before failure, without touching the other architecture's checksum.
    if '  - arch == "x86_64":\n' in text:
        text = re.sub(r'(?m)(^  - arch == "x86_64":\n)((?:^ {4,}[^\n]*\n)+)',
                      lambda m: m[1] + repin(m[2]), text)
    else:
        text = repin(text)
    path.write_text(header + "sources:\n" + text)
    if os.environ.get("FAIL_ELEMENT") == args[-1]:
        sys.exit(1)
elif name == "just" and args[0] == "patch-sync":
    queue = pathlib.Path("patches/freedesktop-sdk")
    for path in queue.iterdir():
        path.unlink()
    (queue / "new.patch").write_text("new upstream patch")
    pathlib.Path("patches/freedesktop-sdk.manifest.json").write_text("new manifest")
elif name == "just" and args[0] == "patch-drift-check":
    if os.environ.get("FAIL_DRIFT"):
        sys.exit(1)
else:
    raise AssertionError((name, args))
'''


GENERATOR_STUB = r'''import json, os, pathlib, re, sys
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps(["generator", *sys.argv[1:]]) + "\n")
path = pathlib.Path("elements/bluefin/ghostty.bst")
path.write_text(re.sub(r"ghostty_releases:[0-9.]+/ghostty-[0-9.]+",
                       f"ghostty_releases:{sys.argv[1]}/ghostty-{sys.argv[1]}", path.read_text()))
if os.environ.get("FAIL_GENERATOR"):
    sys.exit(1)
'''


class CliTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        (self.root / "scripts").mkdir()
        shutil.copy2(REPOSITORY / "scripts/update_sources.py", self.root / "scripts")
        (self.root / ".github/scripts").mkdir(parents=True)
        shutil.copy2(REPOSITORY / ".github/scripts/track_bundle.py", self.root / ".github/scripts")
        paths = [x[0] for x in updater.TRACKED + updater.KERNELS] + list(updater.RELEASES)
        paths += ["gnome-build-meta.bst", "freedesktop-sdk.bst",
                  "plugins/buildstream-plugins-community.bst", *updater.DERIVED]
        for element in paths:
            dest = self.root / "elements" / element
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPOSITORY / "elements" / element, dest)
        queue = self.root / "patches/freedesktop-sdk"
        queue.mkdir(parents=True)
        (queue / "local.patch").write_text("starting local edits")
        (self.root / "patches/freedesktop-sdk.manifest.json").write_text("starting manifest")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("gh", "just", "curl"):
            path = self.bin / name
            path.write_text(f"#!{sys.executable}\n" + STUB)
            path.chmod(0o755)
        # The Ghostty generator downloads; stand in with a recorder that
        # rewrites the release version (and can fail after a partial write).
        generator = self.root / updater.RELEASES["bluefin/ghostty.bst"].generator
        generator.parent.mkdir(parents=True)
        generator.write_text(GENERATOR_STUB)
        self.log = self.root / "calls.jsonl"

    def cli(self, *args, **env):
        return subprocess.run([sys.executable, str(self.root / "scripts/update_sources.py"), *args],
                              cwd=self.root, text=True, capture_output=True,
                              env={**os.environ, "PATH": f"{self.bin}:{os.environ['PATH']}",
                                   "CALL_LOG": str(self.log), **env})

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def init_recording_repo(self):
        # record-element compares against HEAD. Use a disposable fixture repo,
        # never the developer's checkout, to exercise the real recorder.
        for args in (["init", "-q"],
                     ["add", "--", "elements/core/linux-fdsdk.bst", "elements/core/linux-ogc.bst"],
                     ["-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                      "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
                      "commit", "-qm", "fixture"]):
            subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True)

    def snapshot(self):
        return {str(p.relative_to(self.root)): p.read_bytes()
                for name in ("elements", "patches") for p in (self.root / name).rglob("*")
                if p.is_file()}

    def test_release_tracks_only_x86_and_records_untouched_arm(self):
        path = self.root / "elements/bluefin/gum.bst"
        arm_block = re.search(r'(?m)^  - arch == "aarch64":\n(?:^ {4,}[^\n]*\n)+', path.read_text())[0]
        result = self.cli("--element", "bluefin/gum.bst", "--record-dir", "tracked")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertEqual(calls[0][0:2], ["gh", "api"])
        self.assertEqual([c[c.index("arch") + 1] for c in calls[1:]], ["x86_64"])
        self.assertIn(arm_block, path.read_text())
        meta = json.loads((self.root / "tracked/meta/gum.json").read_text())
        self.assertIn("v99.88.77", meta["title"])
        self.assertEqual((self.root / "tracked/files/elements/bluefin/gum.bst").read_bytes(),
                         (self.root / "elements/bluefin/gum.bst").read_bytes())

    def test_generated_release_regenerates_without_tracking(self):
        path = self.root / "elements/bluefin/ghostty.bst"
        old = re.search(r"ghostty_releases:([0-9.]+)/", path.read_text())[1]
        result = self.cli("--element", "bluefin/ghostty.bst", "--record-dir", "tracked")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertEqual(calls[0][0:3], ["gh", "api", "repos/ghostty-org/ghostty/tags?per_page=100"])
        self.assertEqual(calls[1:], [["generator", "99.88.77"]])
        self.assertIn("ghostty_releases:99.88.77/", path.read_text())
        meta = json.loads((self.root / "tracked/meta/ghostty.json").read_text())
        self.assertEqual(meta["title"], f"chore(deps): update ghostty {old} -> 99.88.77")
        self.assertIn(f"compare/v{old}...v99.88.77", meta["links"])

    def test_generated_release_up_to_date_or_failed_leaves_element(self):
        path = self.root / "elements/bluefin/ghostty.bst"
        tag = "v" + re.search(r"ghostty_releases:([0-9.]+)/", path.read_text())[1]
        before = self.snapshot()
        for env in ({"RELEASE_TAG": tag}, {"FAIL_GENERATOR": "1"}, {"RELEASE_TAG": "tip"}):
            with self.subTest(env=env):
                self.log.unlink(missing_ok=True)
                result = self.cli("--element", "bluefin/ghostty.bst", "--record-dir", "tracked", **env)
                self.assertEqual(result.returncode, 0 if "RELEASE_TAG" in env and env["RELEASE_TAG"] == tag else 1)
                self.assertEqual(self.snapshot(), before)
                self.assertFalse((self.root / "tracked/meta").exists())
                if "FAIL_GENERATOR" not in env:
                    self.assertEqual([c[0] for c in self.calls()], ["gh"])

    def test_tracking_failure_restores_entire_element_and_records_nothing(self):
        path = self.root / "elements/bluefin/gum.bst"
        path.write_text(path.read_text() + "\n# uncommitted user edit\n")
        before = self.snapshot()
        result = self.cli("--element", "bluefin/gum.bst", "--record-dir", "tracked",
                          FAIL_ELEMENT="bluefin/gum.bst")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse((self.root / "tracked/meta").exists())

    def test_oci_source_tracks_only_x86_without_release_lookup(self):
        path = self.root / "elements/bluefin/brew-tarball.bst"
        arm_block = re.search(r'(?m)^  - arch == "aarch64":\n(?:^ {4,}[^\n]*\n)+', path.read_text())[0]
        result = self.cli("--element", "bluefin/brew-tarball.bst")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls()), 1)
        self.assertEqual([c[c.index("arch") + 1] for c in self.calls()], ["x86_64"])
        self.assertIn(arm_block, path.read_text())
        self.assertFalse((self.root / "tracked/meta").exists())

    def test_unchanged_release_does_not_track(self):
        path = self.root / "elements/bluefin/gum.bst"
        tag = re.search(r"download/(v[^/]+)/", path.read_text())[1]
        before = self.snapshot()
        result = self.cli("--element", "bluefin/gum.bst", RELEASE_TAG=tag)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls()), 1)
        self.assertEqual(self.snapshot(), before)

    def test_kernel_group_updates_both_and_synchronizes_ogc_suffix(self):
        result = self.cli("--group", "kernels")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [
            ["just", "bst", "--no-interactive", "-o", "arch", "x86_64",
             "source", *command, element]
            for element, _, _ in updater.KERNELS
            for command in (["track"], ["checkout", "--deps", "none", "--directory",
                                         f".source-check/{Path(element).stem}"])
        ])
        text = (self.root / "elements/core/linux-ogc.bst").read_text()
        self.assertIn("ogc-localversion: '-ogc2'", text)
        self.assertIn(re.search(r"track: .*", (REPOSITORY / "elements/core/linux-ogc.bst").read_text())[0],
                      text)
        self.assertIn("NVIDIA", result.stdout)
        self.assertNotIn("gh", [call[0] for call in self.calls()])

    def test_next_kernel_patterns_and_rc_refs_are_preserved(self):
        linux = self.root / "elements/core/linux-fdsdk.bst"
        ogc = self.root / "elements/core/linux-ogc.bst"
        linux.write_text(re.sub(r"track: v[0-9.]+\*\n(  exclude:\n(  - \S+\n)+)?", "track: v*\n",
                                linux.read_text()))
        ogc.write_text(re.sub(r"track: v[0-9.]+\*-ogc\*\n", "track: v*-ogc*\n", ogc.read_text()))
        result = self.cli("--group", "kernels", KERNEL_REF=f"v7.3-rc4-0-g{SHA}",
                          OGC_REF=f"v7.3-rc4-ogc3-0-g{SHA}")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("track: v*\n", linux.read_text())
        self.assertIn("track: v*-ogc*\n", ogc.read_text())
        self.assertIn("ogc-localversion: '-ogc3'", ogc.read_text())

    def test_bad_ogc_ref_rolls_back_ref_and_localversion_together(self):
        before = self.snapshot()
        result = self.cli("--element", "core/linux-ogc.bst", OGC_REF=SHA)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.snapshot(), before)

    def test_failed_kernel_keeps_other_successful_kernel(self):
        ogc = self.root / "elements/core/linux-ogc.bst"
        before = ogc.read_bytes()
        result = self.cli("--group", "kernels", FAIL_ELEMENT="core/linux-ogc.bst")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(ogc.read_bytes(), before)
        self.assertIn(f"v7.2.7-0-g{SHA}",
                      (self.root / "elements/core/linux-fdsdk.bst").read_text())

    def test_kernel_patch_failure_restores_local_edits_and_records_nothing(self):
        for element, _, _ in updater.KERNELS:
            with self.subTest(element=element):
                path = self.root / "elements" / element
                path.write_text(path.read_text() + "\n# uncommitted local edit\n")
                if element == "core/linux-ogc.bst":
                    path.write_text(path.read_text().replace("'-ogc2'", "'-ogc1'"))
                before = self.snapshot()
                result = self.cli("--element", element, "--record-dir", "tracked",
                                  FAIL_CHECKOUT=element)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn("Failed to apply patches", result.stderr)
                self.assertEqual(self.snapshot(), before)
                self.assertFalse((self.root / "tracked/meta").exists())

    def test_kernel_patch_failure_keeps_and_records_other_successful_kernel(self):
        self.init_recording_repo()
        ogc = self.root / "elements/core/linux-ogc.bst"
        before = ogc.read_bytes()
        result = self.cli("--group", "kernels", "--record-dir", "tracked",
                          FAIL_CHECKOUT="core/linux-ogc.bst")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertEqual(ogc.read_bytes(), before)
        recorded = self.root / "tracked/files/elements/core"
        self.assertEqual((recorded / "linux-fdsdk.bst").read_bytes(),
                         (self.root / "elements/core/linux-fdsdk.bst").read_bytes())
        self.assertFalse((recorded / "linux-ogc.bst").exists())

    def test_unchanged_kernel_ref_still_checks_patches(self):
        path = self.root / "elements/core/linux-ogc.bst"
        ref = re.search(r"^  ref: (\S+)$", path.read_text(), re.MULTILINE)[1]
        before = self.snapshot()
        result = self.cli("--element", "core/linux-ogc.bst", OGC_REF=ref,
                          FAIL_CHECKOUT="core/linux-ogc.bst")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("checkout", self.calls()[-1])
        self.assertEqual(self.snapshot(), before)

    def test_successful_kernel_check_records_synchronized_suffix(self):
        self.init_recording_repo()
        result = self.cli("--element", "core/linux-ogc.bst", "--record-dir", "tracked",
                          OGC_REF=f"v7.2.9-ogc3-0-g{SHA}")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("checkout", self.calls()[-1])
        recorded = self.root / "tracked/files/elements/core/linux-ogc.bst"
        self.assertIn("ogc-localversion: '-ogc3'", recorded.read_text())
        self.assertEqual(recorded.read_bytes(),
                         (self.root / "elements/core/linux-ogc.bst").read_bytes())

    def test_tailscale_current_package_does_not_follow_newer_github_tag(self):
        before = self.snapshot()
        text = (self.root / "elements/bluefin/tailscale.bst").read_text()
        filename = re.search(r"tailscale_[0-9.]+_amd64\.tgz", text)[0]
        result = self.cli("--element", "bluefin/tailscale.bst", "--record-dir", "tracked",
                          TAILSCALE_FEED=json.dumps({"Tarballs": {"amd64": filename}}),
                          RELEASE_TAG="v99.88.77")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(self.calls(), [["curl", "-fsSL", updater.TAILSCALE_FEED]])
        self.assertEqual(self.snapshot(), before)
        self.assertFalse((self.root / "tracked/meta").exists())

    def test_tailscale_new_package_tracks_checksum_and_preserves_arm(self):
        path = self.root / "elements/bluefin/tailscale.bst"
        original = path.read_text()
        arm = re.search(r'(?m)^  - arch == "aarch64":\n(?:^ {4,}[^\n]*\n)+', original)[0]
        result = self.cli("--element", "bluefin/tailscale.bst", "--record-dir", "tracked")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [["curl", "-fsSL", updater.TAILSCALE_FEED],
                         ["just", "bst", "--no-interactive", "-o", "arch", "x86_64",
                          "source", "track", "bluefin/tailscale.bst"]])
        self.assertIn("tailscale_pkgs:tailscale_99.88.77_amd64.tgz", path.read_text())
        self.assertIn("ref: " + "d" * 64, path.read_text())
        self.assertIn(arm, path.read_text())
        meta = json.loads((self.root / "tracked/meta/tailscale.json").read_text())
        self.assertIn("99.88.77", meta["title"])
        self.assertEqual((self.root / "tracked/files/elements/bluefin/tailscale.bst").read_text(),
                         path.read_text())

    def test_tailscale_bad_feed_or_failed_download_preserves_pin_and_records_nothing(self):
        path = self.root / "elements/bluefin/tailscale.bst"
        path.write_text(path.read_text() + "\n# local edit\n")
        before = self.snapshot()
        for env in ({"TAILSCALE_FEED": "not JSON"}, {"TAILSCALE_FEED": "{}"},
                    {"FAIL_FEED": "1"}, {"FAIL_ELEMENT": "bluefin/tailscale.bst"}):
            with self.subTest(env=env):
                self.log.unlink(missing_ok=True)
                result = self.cli("--element", "bluefin/tailscale.bst", "--record-dir", "tracked", **env)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(self.snapshot(), before)
                self.assertFalse((self.root / "tracked/meta").exists())
                self.assertNotIn("gh", [c[0] for c in self.calls()])
                if "FAIL_ELEMENT" not in env:
                    self.assertEqual(len(self.calls()), 1)

    def test_core_derives_pin_and_syncs_patches_without_independent_sdk_track(self):
        result = self.cli("--group", "core-junctions")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertEqual(calls[0][-1], "gnome-build-meta.bst")
        self.assertIn(f"ref={SHA}", calls[1][-1])
        self.assertIn("elements%2Fplugins%2Fbuildstream-plugins-community.bst", calls[2][-1])
        self.assertIn(f"ref={SHA}", calls[2][-1])
        self.assertIn("elements%2Fcore-deps%2Fvte.bst", calls[3][-1])
        self.assertIn(f"ref={SHA}", calls[3][-1])
        self.assertIn("elements%2Fcomponents%2Falsa-lib.bst", calls[4][-1])
        self.assertEqual(calls[5][-1], updater.ALSA_UTILS.feed)
        self.assertEqual(calls[6], ["just", "bst", "--no-interactive", "-o", "arch", "x86_64",
                                    "source", "track", "bluefin/alsa-utils.bst"])
        self.assertEqual(calls[7:], [["just", "patch-sync"], ["just", "patch-drift-check"]])
        vte = (self.root / "elements/bluefin/vte.bst").read_text()
        self.assertIn("url: gnome_downloads:vte/99.88/vte-99.88.77.tar.xz\n  ref: " + "a" * 64, vte)
        # The alsa-lib 9.8.7.1 hotfix pairs with alsa-utils 9.8.7, never 9.8.8.
        alsa = (self.root / "elements/bluefin/alsa-utils.bst").read_text()
        self.assertIn("url: alsa_project:utils/alsa-utils-9.8.7.tar.bz2\n", alsa)
        self.assertIn("sdk-99-0-g" + "c" * 40,
                      (self.root / "elements/freedesktop-sdk.bst").read_text())
        plugins = (self.root / "elements/plugins/buildstream-plugins-community.bst").read_text()
        self.assertIn("buildstream_plugins_community-9.9.9.tar.gz\n  ref: " + "f" * 64, plugins)

    def test_core_failure_restores_both_pins_patch_deletions_additions_and_manifest(self):
        before = self.snapshot()
        result = self.cli("--group", "core-junctions", FAIL_DRIFT="1")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.snapshot(), before)

    def test_invalid_upstream_pin_fails_before_patch_sync(self):
        before = self.snapshot()
        result = self.cli("--group", "core-junctions", UPSTREAM_FDSDK="not a junction")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(len(self.calls()), 2)

    def test_invalid_upstream_plugins_pin_restores_core_and_skips_patch_sync(self):
        before = self.snapshot()
        result = self.cli("--group", "core-junctions", UPSTREAM_PLUGINS="kind: junction")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(len(self.calls()), 3)

    def test_core_rejects_unreadable_derived_pins_and_restores_everything(self):
        before = self.snapshot()
        for env in ({"UPSTREAM_VTE": "kind: meson\nsources:\n- kind: git_repo\n"},
                    {"UPSTREAM_ALSA": "sources:\n- kind: git_repo\n  ref: main\n"},
                    {"UPSTREAM_ALSA": "  ref: v5.5.5-0-g" + "a" * 40 + "\n"}):
            with self.subTest(env=env):
                result = self.cli("--group", "core-junctions", **env)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(self.snapshot(), before)

    def test_feed_release_tracks_newest_in_series_and_never_moves_backwards(self):
        path = self.root / "elements/bluefin-nvidia/nvidia-drivers.bst"
        result = self.cli("--element", "bluefin-nvidia/nvidia-drivers.bst", "--record-dir", "tracked")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("nvidia-version: '615.99.77'", path.read_text())
        meta = json.loads((self.root / "tracked/meta/nvidia-drivers.json").read_text())
        self.assertIn("-> 615.99.77", meta["title"])
        self.assertIn("NVIDIA kernel modules", meta["note"])
        before = self.snapshot()
        for body in ("href='615.1.2/'", '{"version_tag": 1}'):
            for element in ("bluefin-nvidia/nvidia-drivers.bst",
                            "bluefin/shell-extensions/tilingshell.bst"):
                result = self.cli("--element", element, FEED_BODY=body)
                if (body.startswith("href")) == ("nvidia" in element):
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("keeping it", result.stdout)
                else:
                    self.assertEqual(result.returncode, 1)
                self.assertEqual(self.snapshot(), before)

    def test_ego_feed_asks_for_the_shipped_shell_version(self):
        result = self.cli("--element", "bluefin/shell-extensions/tilingshell.bst")
        self.assertEqual(result.returncode, 0, result.stderr)
        shell = re.search(r"track: gnome-([0-9]+)",
                          (self.root / "elements/gnome-build-meta.bst").read_text())[1]
        self.assertTrue(self.calls()[0][-1].endswith(f"&shell_version={shell}"))
        self.assertIn("version_tag=99999",
                      (self.root / "elements/bluefin/shell-extensions/tilingshell.bst").read_text())

    def test_patched_elements_must_still_apply_their_patches(self):
        for element in ("bluefin/open-vm-tools.bst", "bluefin/shell-extensions/tailscale-qs.bst"):
            with self.subTest(element=element):
                path = self.root / "elements" / element
                path.write_text(path.read_text() + "\n# local edit\n")
                before = self.snapshot()
                self.log.unlink(missing_ok=True)
                result = self.cli("--element", element, "--record-dir", "tracked",
                                  FAIL_CHECKOUT=element)
                self.assertEqual(result.returncode, 1)
                self.assertIn("checkout", self.calls()[-1])
                self.assertEqual(self.snapshot(), before)
                self.assertFalse((self.root / "tracked/meta").exists())
                self.assertFalse((self.root / ".source-check").exists())
        result = self.cli("--element", "bluefin/open-vm-tools.bst")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("open-vm-tools-99.88.77-12345.tar.gz",
                      (self.root / "elements/bluefin/open-vm-tools.bst").read_text())
        self.assertFalse((self.root / ".source-check").exists())

    def test_failures_are_recorded_for_the_bundle_pr(self):
        result = self.cli("--element", "bluefin/gum.bst", "--record-dir", "tracked",
                          RELEASE_TAG="not-a-tag")
        self.assertEqual(result.returncode, 1)
        record = json.loads((self.root / "tracked/failed/gum.json").read_text())
        self.assertEqual(record["element"], "bluefin/gum.bst")
        self.assertIn("Unexpected release tag", record["error"])
        # The matrix records updates in a later step, so it names the directory itself.
        result = self.cli("--element", "bluefin/brlaser.bst", "--failure-dir", "elsewhere",
                          FAIL_ELEMENT="bluefin/brlaser.bst")
        self.assertEqual(result.returncode, 1)
        record = json.loads((self.root / "elsewhere/failed/brlaser.json").read_text())
        self.assertIn("exited 1", record["error"])
        self.assertFalse((self.root / "tracked/failed/brlaser.json").exists())

    def test_pinned_reasons_are_printed_offline(self):
        result = self.cli("--pinned")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), updater.PINNED)
        self.assertFalse(self.log.exists())

    def test_failed_release_does_not_drop_other_records(self):
        result = self.cli("--group", "tarballs", "--record-dir", "tracked",
                          FAIL_ELEMENT="bluefin/tailscale.bst")
        self.assertEqual(result.returncode, 1)
        # Tailscale simulates a 404; every other release is still recorded.
        self.assertEqual(sorted(p.stem for p in (self.root / "tracked/meta").glob("*.json")),
                         sorted(Path(e).stem
                                for e in updater.RELEASES if e != "bluefin/tailscale.bst"))


class NextKernelPolicyTests(unittest.TestCase):
    """Execute the PR-policy shell with stubbed git/gh, never mutate a remote."""

    def policy(self, *, kernels=True, existing="7", fail_disable=False, auto_merge="true"):
        workflow = (REPOSITORY / ".github/workflows/track-next-junctions.yml").read_text()
        script = textwrap.dedent(workflow.split(
            "      - name: Create or update PR against next\n", 1)[1].split("        run: |\n", 1)[1])
        stub = r'''import json, os, pathlib, sys
name, args = pathlib.Path(sys.argv[0]).name, sys.argv[1:]
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps([name, *args]) + "\n")
if name == "git" and args[:3] == ["diff", "--cached", "--quiet"]:
    sys.exit(1 if "--" not in args or os.environ["KERNEL_CHANGES"] == "1" else 0)
if name == "gh":
    if args[:2] == ["pr", "list"]:
        print(os.environ["EXISTING_PR"])
    elif args[:2] == ["pr", "view"] and "autoMergeRequest" in args:
        print(os.environ["AUTO_MERGE"])
    elif args[:2] in (["pr", "view"], ["pr", "create"]):
        print("https://github.com/example/repo/pull/7")
    elif "--disable-auto" in args and os.environ["FAIL_DISABLE"] == "1":
        sys.exit(1)
'''
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ("git", "gh"):
                tool = root / name
                tool.write_text(f"#!{sys.executable}\n" + stub)
                tool.chmod(0o755)
            log = root / "calls.jsonl"
            result = subprocess.run(["bash", "-euo", "pipefail", "-c", script], cwd=root,
                                    text=True, capture_output=True, env={**os.environ,
                                    "PATH": f"{root}:{os.environ['PATH']}", "CALL_LOG": str(log),
                                    "KERNEL_CHANGES": str(int(kernels)), "EXISTING_PR": existing,
                                    "FAIL_DISABLE": str(int(fail_disable)), "AUTO_MERGE": auto_merge})
            return result, [json.loads(line) for line in log.read_text().splitlines()]

    def test_existing_kernel_pr_disables_auto_before_push(self):
        result, calls = self.policy()
        self.assertEqual(result.returncode, 0, result.stderr)
        disabled = next(i for i, call in enumerate(calls) if "--disable-auto" in call)
        pushed = next(i for i, call in enumerate(calls) if call[:2] == ["git", "push"])
        self.assertLess(disabled, pushed)
        self.assertFalse(any("--auto" in call for call in calls))

    def test_kernel_pr_already_without_auto_can_be_refreshed(self):
        result, calls = self.policy(auto_merge="false")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(any(call[:2] == ["git", "push"] for call in calls))
        self.assertFalse(any("--disable-auto" in call or "--auto" in call for call in calls))

    def test_unknown_auto_merge_state_prevents_push(self):
        result, calls = self.policy(auto_merge="")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call[:2] == ["git", "push"] for call in calls))

    def test_new_kernel_pr_does_not_enable_auto(self):
        result, calls = self.policy(existing="")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(any(call[:3] == ["gh", "pr", "create"] for call in calls))
        self.assertFalse(any("--auto" in call for call in calls))

    def test_junction_only_pr_retains_auto_merge(self):
        result, calls = self.policy(kernels=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(any("--auto" in call for call in calls))
        self.assertFalse(any("--disable-auto" in call for call in calls))

    def test_failure_to_disable_auto_prevents_push(self):
        result, calls = self.policy(fail_disable=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call[:2] == ["git", "push"] for call in calls))


class GhosttyZigTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location(
            "generate_ghostty_sources", REPOSITORY / "files/scripts/generate_ghostty_sources.py")
        self.gen = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.gen)

    def entry(self, version, sha="e" * 64):
        return {"x86_64-linux": {"tarball": f"https://ziglang.org/download/{version}/"
                                            f"zig-x86_64-linux-{version}.tar.xz", "shasum": sha}}

    def test_zig_follows_the_newest_patch_of_ghosttys_minor(self):
        index = {"master": {}, **{v: self.entry(v) for v in ("0.17.0", "0.17.2", "0.18.0", "0.16.9")}}
        self.assertEqual(self.gen.zig_for("0.17.0", index), ("0.17.2", "e" * 64))
        self.assertEqual(self.gen.zig_for("0.16.0", index)[0], "0.16.9")
        for bad in ({"0.19.0": self.entry("0.19.0", "not-a-sha")},
                    {"0.19.0": {"x86_64-linux": {"tarball": "https://evil.invalid/zig.tar.xz",
                                                 "shasum": "e" * 64}}}, {}):
            with self.subTest(index=bad), self.assertRaises(ValueError):
                self.gen.zig_for("0.19.0", bad)

    def test_only_the_x86_zig_pin_moves(self):
        text = (REPOSITORY / "elements/bluefin/zig.bst").read_text()
        arm = re.search(r'(?m)^  - arch == "aarch64":\n(?:^ {4,}[^\n]*\n)+', text)[0]
        updated = self.gen.pin_zig(text, "9.8.7", "f" * 64)
        self.assertIn("url: ziglang:download/9.8.7/zig-x86_64-linux-9.8.7.tar.xz\n      ref: " + "f" * 64,
                      updated)
        self.assertIn(arm, updated)
        with self.assertRaises(ValueError):
            self.gen.pin_zig("kind: manual\n", "9.8.7", "f" * 64)


class WiringTests(unittest.TestCase):
    def test_ci_uses_shared_updater_and_keeps_partial_artifacts(self):
        text = (REPOSITORY / ".github/workflows/track-bst-sources.yml").read_text()
        self.assertIn("python3 scripts/update_sources.py --matrix", text)
        self.assertIn("fromJSON(needs.tracking-matrix.outputs.matrix)", text)
        self.assertIn('just update-sources --element "$ELEMENT" --failure-dir "$RUNNER_TEMP/tracked"', text)
        self.assertIn("name: track-failed-${{ strategy.job-index }}", text)
        self.assertIn('--pinned "$RUNNER_TEMP/pinned.json"', text)
        self.assertIn('just update-sources --group tarballs --record-dir "$RUNNER_TEMP/tracked"', text)
        self.assertIn("- name: Upload updates\n        if: ${{ !cancelled() }}", text)
        self.assertNotIn("source track", text)
        for name in ("track-bst-sources.yml", "track-next-junctions.yml"):
            self.assertIn("just update-sources --group core-junctions",
                          (REPOSITORY / ".github/workflows" / name).read_text())
        next_workflow = (REPOSITORY / ".github/workflows/track-next-junctions.yml").read_text()
        self.assertIn("just update-sources --group kernels", next_workflow)
        self.assertIn("elements/core/linux-fdsdk.bst elements/core/linux-ogc.bst", next_workflow)
        justfile = (REPOSITORY / "Justfile").read_text()
        self.assertIn('[positional-arguments]\nupdate-sources *FLAGS:\n'
                      '    python3 scripts/update_sources.py "$@"', justfile)
        self.assertIn("scripts.test_update_sources", justfile)


if __name__ == "__main__":
    unittest.main()
