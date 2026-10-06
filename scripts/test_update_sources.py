"""Offline coverage for the shared local/CI source updater."""

import contextlib
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
        self.assertIn("bluefin/wallpapers.bst", err.getvalue())

    def test_matrix_preserves_review_notes_and_adds_oci_source(self):
        items = {x["element"]: x for x in updater.matrix()["include"]}
        self.assertEqual(len(items), 20)
        for kernel, _, _ in updater.KERNELS:
            self.assertIn("NVIDIA build", items[kernel]["note"])
        self.assertIn("bluefin/brew-tarball.bst", items)
        self.assertEqual(items["gnomeos-deps/bootc.bst"]["note"], "review: core system component")
        self.assertEqual(items["bluefin/shell-extensions/gradia-capture.bst"]["note"],
                         "review: unreleased branch head")
        for element in items:
            self.assertTrue((REPOSITORY / "elements" / element).is_file())


class RewriteTests(unittest.TestCase):
    def test_every_release_updates_only_urls_and_is_idempotent(self):
        for element, release in updater.RELEASES.items():
            with self.subTest(element=element):
                original = (REPOSITORY / "elements" / element).read_text()
                tag = "bluefin-v2099-01-01" if "wallpapers" in element else "v99.88.77"
                updated, old = updater.rewrite_release(original, release, tag)
                self.assertNotEqual(updated, original)
                self.assertTrue(old)
                unchanged = lambda text: [line for line in text.splitlines()
                                           if not line.lstrip().startswith("url:")]
                self.assertEqual(unchanged(updated), unchanged(original))
                self.assertEqual(updater.rewrite_release(updated, release, tag)[0], updated)

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
if name == "gh":
    assert args[0] == "api" and args[1].startswith("repos/")
    print(os.environ.get("RELEASE_TAG", "v99.88.77"))
elif name == "curl" and args[-1] == "https://pkgs.tailscale.com/stable/?mode=json":
    if os.environ.get("FAIL_FEED"):
        sys.exit(22)
    print(os.environ.get("TAILSCALE_FEED", json.dumps({"Tarballs": {
        "amd64": "tailscale_99.88.77_amd64.tgz"}})))
elif name == "curl":
    print(os.environ.get("UPSTREAM_FDSDK", "kind: junction\nsources:\n- kind: git_repo\n  url: gitlab:freedesktop-sdk/freedesktop-sdk.git\n  track: stable\n  ref: sdk-99-0-g" + "c" * 40))
elif name == "just" and args[0] == "bst" and "fetch" in args:
    assert args == ["bst", "--no-interactive", "-o", "arch", "x86_64",
                    "source", "fetch", "--deps", "none", args[-1]]
    assert args[-1] in ("core/linux-fdsdk.bst", "core/linux-ogc.bst")
    if os.environ.get("FAIL_FETCH") == args[-1]:
        print("Failed to apply kernel patches", file=sys.stderr)
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
        paths += ["gnome-build-meta.bst", "freedesktop-sdk.bst"]
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

    def test_tracking_failure_restores_entire_element_and_records_nothing(self):
        path = self.root / "elements/bluefin/gum.bst"
        path.write_text(path.read_text() + "\n# uncommitted user edit\n")
        before = self.snapshot()
        result = self.cli("--element", "bluefin/gum.bst", "--record-dir", "tracked",
                          FAIL_ELEMENT="bluefin/gum.bst")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse((self.root / "tracked").exists())

    def test_oci_source_tracks_only_x86_without_release_lookup(self):
        path = self.root / "elements/bluefin/brew-tarball.bst"
        arm_block = re.search(r'(?m)^  - arch == "aarch64":\n(?:^ {4,}[^\n]*\n)+', path.read_text())[0]
        result = self.cli("--element", "bluefin/brew-tarball.bst")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls()), 1)
        self.assertEqual([c[c.index("arch") + 1] for c in self.calls()], ["x86_64"])
        self.assertIn(arm_block, path.read_text())
        self.assertFalse((self.root / "tracked").exists())

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
            for command in (["track"], ["fetch", "--deps", "none"])
        ])
        text = (self.root / "elements/core/linux-ogc.bst").read_text()
        self.assertIn("ogc-localversion: '-ogc2'", text)
        self.assertIn("track: v7.2.*-ogc*", text)
        self.assertIn("NVIDIA", result.stdout)
        self.assertNotIn("gh", [call[0] for call in self.calls()])

    def test_next_kernel_patterns_and_rc_refs_are_preserved(self):
        linux = self.root / "elements/core/linux-fdsdk.bst"
        ogc = self.root / "elements/core/linux-ogc.bst"
        linux.write_text(linux.read_text().replace("track: v7.2.*", "track: v*"))
        ogc.write_text(ogc.read_text().replace("track: v7.2.*-ogc*", "track: v*-ogc*"))
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

    def test_kernel_fetch_failure_restores_local_edits_and_records_nothing(self):
        for element, _, _ in updater.KERNELS:
            with self.subTest(element=element):
                path = self.root / "elements" / element
                path.write_text(path.read_text() + "\n# uncommitted local edit\n")
                if element == "core/linux-ogc.bst":
                    path.write_text(path.read_text().replace("'-ogc2'", "'-ogc1'"))
                before = self.snapshot()
                result = self.cli("--element", element, "--record-dir", "tracked",
                                  FAIL_FETCH=element)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn("Failed to apply kernel patches", result.stderr)
                self.assertEqual(self.snapshot(), before)
                self.assertFalse((self.root / "tracked").exists())

    def test_kernel_fetch_failure_keeps_and_records_other_successful_kernel(self):
        self.init_recording_repo()
        ogc = self.root / "elements/core/linux-ogc.bst"
        before = ogc.read_bytes()
        result = self.cli("--group", "kernels", "--record-dir", "tracked",
                          FAIL_FETCH="core/linux-ogc.bst")
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
                          FAIL_FETCH="core/linux-ogc.bst")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("fetch", self.calls()[-1])
        self.assertEqual(self.snapshot(), before)

    def test_successful_kernel_fetch_records_synchronized_suffix(self):
        self.init_recording_repo()
        result = self.cli("--element", "core/linux-ogc.bst", "--record-dir", "tracked",
                          OGC_REF=f"v7.2.9-ogc3-0-g{SHA}")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("fetch", self.calls()[-1])
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
        self.assertFalse((self.root / "tracked").exists())

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
                self.assertFalse((self.root / "tracked").exists())
                self.assertNotIn("gh", [c[0] for c in self.calls()])
                if "FAIL_ELEMENT" not in env:
                    self.assertEqual(len(self.calls()), 1)

    def test_core_derives_pin_and_syncs_patches_without_independent_sdk_track(self):
        result = self.cli("--group", "core-junctions")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertEqual(calls[0][-1], "gnome-build-meta.bst")
        self.assertIn(f"ref={SHA}", calls[1][-1])
        self.assertEqual(calls[2:], [["just", "patch-sync"], ["just", "patch-drift-check"]])
        self.assertIn("sdk-99-0-g" + "c" * 40,
                      (self.root / "elements/freedesktop-sdk.bst").read_text())

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

    def test_failed_release_does_not_drop_other_records(self):
        result = self.cli("--group", "tarballs", "--record-dir", "tracked",
                          FAIL_ELEMENT="bluefin/tailscale.bst")
        self.assertEqual(result.returncode, 1)
        # Wallpaper tag is deliberately invalid; Tailscale simulates a 404.
        self.assertEqual(sorted(p.stem for p in (self.root / "tracked/meta").glob("*.json")),
                         ["gtk4-layer-shell", "gum", "jetbrains-mono-nerd-font", "uupd"])


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


class WiringTests(unittest.TestCase):
    def test_ci_uses_shared_updater_and_keeps_partial_artifacts(self):
        text = (REPOSITORY / ".github/workflows/track-bst-sources.yml").read_text()
        self.assertIn("python3 scripts/update_sources.py --matrix", text)
        self.assertIn("fromJSON(needs.tracking-matrix.outputs.matrix)", text)
        self.assertIn('just update-sources --element "$ELEMENT"', text)
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
