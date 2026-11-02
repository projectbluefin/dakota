#!/usr/bin/env python3
"""Unit and integration coverage for .github/scripts/track_bundle.py.

The compose tests run the real git plumbing against disposable repositories
with a bare "origin" and a recording `gh` stub on PATH, so branch, push, and
PR decisions are exercised without touching GitHub.
"""

import contextlib
import io
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path
from unittest import mock

REPOSITORY = Path(__file__).resolve().parents[1]
WORKFLOW = REPOSITORY / ".github/workflows/track-bst-sources.yml"
sys.path.insert(0, str(REPOSITORY / ".github/scripts"))

import track_bundle  # noqa: E402

SHA_A = "a" * 40
SHA_B = "b" * 40
SHA_C = "c" * 40

GH_STUB = textwrap.dedent("""\
    #!{python}
    import json, os, sys
    state = os.environ["GH_STUB_STATE"]
    with open(os.path.join(state, "calls.jsonl"), "a") as f:
        stdin = "" if sys.stdin.isatty() else sys.stdin.read()
        f.write(json.dumps({{"argv": sys.argv[1:], "stdin": stdin}}) + "\\n")
    if sys.argv[1:3] == ["pr", "list"]:
        try:
            print(open(os.path.join(state, "open-pr")).read().strip())
        except FileNotFoundError:
            pass
    elif sys.argv[1:3] == ["pr", "create"]:
        print("https://github.com/example/repo/pull/1")
""")


def element(ref: str, url: str = "github:example/widget.git") -> str:
    return f"kind: manual\nsources:\n- kind: git_repo\n  url: {url}\n  ref: {ref}\n"


class VersionFactTests(unittest.TestCase):
    def test_ref_version_strips_describe_suffix(self):
        self.assertEqual(track_bundle.ref_version(f"v2026.08-204-g{SHA_A}"), "v2026.08-204")
        self.assertEqual(track_bundle.ref_version(f"4.4.15-3-g{SHA_A}"), "4.4.15-3")
        self.assertEqual(track_bundle.ref_version("v1.16.14-0"), "v1.16.14-0")

    def test_ref_version_ignores_raw_commits_and_dotless_tags(self):
        self.assertEqual(track_bundle.ref_version(SHA_A), "")
        self.assertEqual(track_bundle.ref_version(f"48-0-g{SHA_A}"), "")
        self.assertEqual(track_bundle.ref_version(""), "")

    def test_ref_sha(self):
        self.assertEqual(track_bundle.ref_sha(f"v1.2-3-g{SHA_A}"), SHA_A)
        self.assertEqual(track_bundle.ref_sha(SHA_B), SHA_B)

    def test_diff_refs_takes_first_removed_and_added(self):
        diff = textwrap.dedent(f"""\
            --- a/elements/x.bst
            +++ b/elements/x.bst
            @@ -1,4 +1,4 @@
            -  ref: v1.0-0-g{SHA_A}
            +  ref: v1.1-0-g{SHA_B}
            -  ref: second-old
            +  ref: second-new
            """)
        self.assertEqual(track_bundle.diff_refs(diff), (f"v1.0-0-g{SHA_A}", f"v1.1-0-g{SHA_B}"))

    def test_ref_shas_is_order_insensitive(self):
        one = f"  ref: {SHA_A}\n  ref: v1-0-g{SHA_B}\n"
        two = f"  ref: v9-0-g{SHA_B}\n  ref: v2-0-g{SHA_A}\n"
        self.assertEqual(track_bundle.ref_shas(one), track_bundle.ref_shas(two))

    def test_upstream_slug(self):
        self.assertEqual(track_bundle.upstream_slug(element("x")), "example/widget")
        self.assertEqual(track_bundle.upstream_slug(element("x", "gnome:foo.git")), "")


class DescribeTests(unittest.TestCase):
    def describe(self, old_ref, new_ref, url="github:example/widget.git", note=""):
        diff = f"-  ref: {old_ref}\n+  ref: {new_ref}\n"
        return track_bundle.describe_element_update(
            "widget", "chore(deps): update widget", "elements/bluefin/widget.bst",
            element(new_ref, url), diff, note)

    def test_versioned_bump(self):
        u = self.describe(f"v1.2-0-g{SHA_A}", f"v1.3-0-g{SHA_B}")
        self.assertEqual(u.title, "chore(deps): update widget: v1.2-0 -> v1.3-0")
        self.assertEqual(u.change, "`v1.2-0` → `v1.3-0`")
        self.assertEqual(u.links, f"[compare](https://github.com/example/widget/compare/{SHA_A}...{SHA_B})")
        self.assertEqual(u.row(), f"| `bluefin/widget.bst` | `v1.2-0` → `v1.3-0` | {u.links} |  |")

    def test_unversioned_bump_falls_back_to_short_commits(self):
        u = self.describe(SHA_A, SHA_B, url="gnome:widget.git", note="review: x")
        self.assertEqual(u.title, "chore(deps): update widget")
        self.assertEqual(u.change, "`aaaaaaaa` → `bbbbbbbb`")
        self.assertEqual(u.links, "")
        self.assertTrue(u.row().endswith("| review: x |"))

    def test_same_version_new_commit_uses_commits(self):
        u = self.describe(f"v1.2-0-g{SHA_A}", f"v1.2-0-g{SHA_B}")
        self.assertEqual(u.title, "chore(deps): update widget")


class BodyTests(unittest.TestCase):
    def updates(self, *notes):
        return [track_bundle.Update(slug=f"e{i}", title=f"chore(deps): update e{i}",
                                    files=[f"elements/bluefin/e{i}.bst"], note=n)
                for i, n in enumerate(notes)]

    def test_callout_only_with_notes(self):
        self.assertNotIn("[!IMPORTANT]", track_bundle.render_body(self.updates("", ""), "u"))
        self.assertIn("[!IMPORTANT]", track_bundle.render_body(self.updates("", "review"), "u"))

    def test_title(self):
        self.assertEqual(track_bundle.bundle_title(self.updates("")), "chore(deps): update e0")
        self.assertEqual(track_bundle.bundle_title(self.updates("", "")),
                         "chore(deps): update 2 BuildStream sources")


class GitFixture(unittest.TestCase):
    """A clone of a bare origin on `testing` holding three elements."""

    ELEMENTS = ("a", "b", "c")

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.origin, self.work = root / "origin.git", root / "work"
        self.tracked, self.state = root / "tracked", root / "gh"
        self.state.mkdir()
        bindir = root / "bin"
        bindir.mkdir()
        stub = bindir / "gh"
        stub.write_text(GH_STUB.format(python=sys.executable))
        stub.chmod(0o755)
        env = {
            "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
            "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
            "GH_STUB_STATE": str(self.state),
            "PATH": f"{bindir}{os.pathsep}{os.environ['PATH']}",
        }
        patcher = mock.patch.dict(os.environ, env)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(self.tmp.cleanup)

        self.git("init", "-q", "--bare", str(self.origin), cwd=root)
        self.git("init", "-q", "--initial-branch=testing", str(self.work), cwd=root)
        self.git("remote", "add", "origin", str(self.origin))
        for name in self.ELEMENTS:
            self.write(name, element(f"v1.0-0-g{SHA_A}"))
        self.git("add", "-A")
        self.git("commit", "-qm", "base")
        self.git("push", "-q", "origin", "testing")
        self.git("fetch", "-q", "origin")

    def git(self, *args, cwd=None):
        return subprocess.run(["git", *args], cwd=cwd or self.work, check=True,
                              text=True, capture_output=True).stdout.strip()

    def path(self, name):
        return f"elements/bluefin/{name}.bst"

    def write(self, name, text):
        target = self.work / self.path(name)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def gh_calls(self):
        log = self.state / "calls.jsonl"
        if not log.exists():
            return []
        return [json.loads(line) for line in log.read_text().splitlines()]


class RecordElementTests(GitFixture):
    def record(self):
        output = self.work / "github-output"
        output.write_text("")
        with mock.patch.dict(os.environ, {"GITHUB_OUTPUT": str(output)}), \
                contextlib.chdir(self.work), contextlib.redirect_stdout(io.StringIO()):
            rc = track_bundle.main(["record-element", "--element", "bluefin/a.bst",
                                    "--title", "chore(deps): update a", "--note", "review",
                                    "--out", str(self.tracked)])
        self.assertEqual(rc, 0)
        return output.read_text()

    def test_unchanged_element_records_nothing(self):
        self.assertEqual(self.record(), "")
        self.assertFalse(self.tracked.exists())

    def test_ref_normalization_records_nothing(self):
        self.write("a", element(f"v1.0-0-g{SHA_A}").replace(f"v1.0-0-g{SHA_A}", SHA_A))
        self.assertEqual(self.record(), "")
        self.assertFalse(self.tracked.exists())

    def test_non_ref_change_is_recorded_even_with_same_commit(self):
        original = element(f"v1.0-0-g{SHA_A}") + "variables:\n  ogc-localversion: '-ogc1'\n"
        self.write("a", original)
        self.git("add", self.path("a"))
        self.git("commit", "-qm", "kernel fixture")
        self.write("a", original.replace("'-ogc1'", "'-ogc2'"))
        self.assertEqual(self.record(), "slug=a\n")
        self.assertIn("ogc-localversion: '-ogc2'",
                      (self.tracked / "files" / self.path("a")).read_text())

    def test_real_change_is_recorded(self):
        self.write("a", element(f"v1.1-0-g{SHA_B}"))
        self.assertEqual(self.record(), "slug=a\n")
        meta = json.loads((self.tracked / "meta/a.json").read_text())
        self.assertEqual(meta["title"], "chore(deps): update a: v1.0-0 -> v1.1-0")
        self.assertEqual(meta["note"], "review")
        self.assertEqual((self.tracked / "files" / self.path("a")).read_text(),
                         element(f"v1.1-0-g{SHA_B}"))


class ComposeTests(GitFixture):
    def track(self, name, sha, note=""):
        """Record `name` at a new version the way a tracking job would."""
        text = element(f"v{sha[0]}-0-g{sha}")
        out = self.tracked / "files" / self.path(name)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text)
        meta = self.tracked / "meta"
        meta.mkdir(parents=True, exist_ok=True)
        update = track_bundle.Update(slug=name, title=f"chore(deps): update {name}",
                                     files=[self.path(name)], change="x", note=note)
        (meta / f"{name}.json").write_text(json.dumps(track_bundle.asdict(update)))

    def compose(self, skip=()):
        self.git("fetch", "-q", "origin")
        with contextlib.redirect_stdout(io.StringIO()):
            result = track_bundle.compose(self.tracked, "auto/track-bundle", "testing",
                                          set(skip), "https://run", repo=self.work)
        self.git("fetch", "-q", "origin")
        return result

    def bundle_subjects(self):
        return self.git("log", "--format=%s", "origin/testing..origin/auto/track-bundle").splitlines()

    def land_on_testing(self, name, sha):
        self.git("checkout", "-q", "-B", "testing", "origin/testing")
        self.write(name, element(f"v{sha[0]}-0-g{sha}"))
        self.git("commit", "-qam", f"land {name}")
        self.git("push", "-q", "origin", "testing")

    def open_pr(self):
        (self.state / "open-pr").write_text("7\n")

    def test_nothing_recorded(self):
        result = self.compose()
        self.assertEqual((result.count, result.pushed), (0, False))
        self.assertEqual(self.gh_calls(), [])

    def test_new_bundle_opens_pr_with_one_commit_per_element(self):
        self.track("a", SHA_B)
        self.track("b", SHA_B, note="review: core")
        result = self.compose()
        self.assertTrue(result.pushed)
        self.assertEqual(self.bundle_subjects(), ["chore(deps): update b", "chore(deps): update a"])
        create = self.gh_calls()[-1]
        self.assertEqual(create["argv"][:2], ["pr", "create"])
        self.assertIn("chore(deps): update 2 BuildStream sources", create["argv"])
        self.assertIn("| `bluefin/b.bst` | x |  | review: core |", create["stdin"])
        self.assertIn("[!IMPORTANT]", create["stdin"])

    def test_skip_holds_element_out(self):
        self.track("a", SHA_B)
        self.track("b", SHA_B)
        self.compose(skip={"b"})
        self.assertEqual(self.bundle_subjects(), ["chore(deps): update a"])

    def test_unchanged_bundle_is_not_pushed_when_base_advances(self):
        self.track("a", SHA_B)
        self.compose()
        self.open_pr()
        tip = self.git("rev-parse", "origin/auto/track-bundle")
        self.land_on_testing("c", SHA_C)
        result = self.compose()
        self.assertFalse(result.pushed)
        self.assertEqual(self.git("rev-parse", "origin/auto/track-bundle"), tip)
        self.assertEqual(self.gh_calls()[-1]["argv"][:3], ["pr", "edit", "7"])

    def test_update_already_on_base_drops_out_without_push(self):
        self.track("a", SHA_B)
        self.track("b", SHA_B)
        self.compose()
        self.open_pr()
        tip = self.git("rev-parse", "origin/auto/track-bundle")
        self.land_on_testing("b", SHA_B)
        result = self.compose()
        self.assertFalse(result.pushed)
        self.assertEqual(self.git("rev-parse", "origin/auto/track-bundle"), tip)
        body = self.gh_calls()[-1]["stdin"]
        self.assertIn("bluefin/a.bst", body)
        self.assertNotIn("bluefin/b.bst", body)

    def test_new_bump_pushes_and_edits_existing_pr(self):
        self.track("a", SHA_B)
        self.compose()
        self.open_pr()
        tip = self.git("rev-parse", "origin/auto/track-bundle")
        self.track("a", SHA_C)
        result = self.compose()
        self.assertTrue(result.pushed)
        self.assertNotEqual(self.git("rev-parse", "origin/auto/track-bundle"), tip)
        self.assertEqual(self.gh_calls()[-1]["argv"][:3], ["pr", "edit", "7"])


class WorkflowWiringTests(unittest.TestCase):
    """Every track_bundle.py call in the workflow must parse against the CLI."""

    def invocations(self):
        text = WORKFLOW.read_text().replace("\\\n", " ")
        return [shlex.split(m.group(1))
                for m in re.finditer(r"python3 \.github/scripts/track_bundle\.py ([^\n]+)", text)]

    def test_invocations_parse(self):
        calls = self.invocations()
        self.assertEqual({c[0] for c in calls}, {"record-element", "compose"})
        for argv in calls:
            with self.subTest(argv=argv[:3]), \
                    mock.patch.object(track_bundle, "cmd_record_element", return_value=0), \
                    mock.patch.object(track_bundle, "cmd_record", return_value=0), \
                    mock.patch.object(track_bundle, "cmd_compose", return_value=0):
                track_bundle.main(argv)


if __name__ == "__main__":
    unittest.main()
