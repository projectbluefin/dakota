"""Run the sync workflow's actual synthesis shell against disposable local Git repos."""
import os
import re
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
WORKFLOW = (REPO / ".github/workflows/sync-next.yml").read_text()
SHELL = textwrap.dedent(WORKFLOW.split(
    "      - name: Synthesize next from testing\n        run: |\n", 1)[1])
MAPS = ("files/filemap.json", "files/fakecap-manifest.tsv")


class SyncNextTests(unittest.TestCase):
    def check_sync(self, *, live_map=False, unrelated=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull,
                       GIT_AUTHOR_NAME="Fixture", GIT_AUTHOR_EMAIL="fixture@example.invalid",
                       GIT_COMMITTER_NAME="Fixture", GIT_COMMITTER_EMAIL="fixture@example.invalid")
            for name in ("NEXT_OWNED", "NEXT_MERGED"):
                # Either a folded list of paths or an explicitly empty string.
                match = re.search(rf'^  {name}: (?:>-\n((?:    [^\n]+\n)+)|""\n)', WORKFLOW, re.M)
                self.assertIsNotNone(match)
                env[name] = " ".join((match[1] or "").split())

            def git(*args):
                return subprocess.run(["git", *args], cwd=root, env=env, check=True,
                                      text=True, capture_output=True).stdout.strip()

            git("init", "--initial-branch=testing")
            owned = "elements/gnome-build-meta.bst"
            for path in (*MAPS, owned, "unrelated.txt"):
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("base\n")
            git("add", "--", *MAPS, owned, "unrelated.txt")
            git("commit", "-m", "base")
            base = git("rev-parse", "HEAD")
            git("rm", "--", *(MAPS[1:] if live_map else MAPS))
            git("commit", "-m", "retire generated maps")
            git("switch", "--no-track", "-c", "next", base)
            for path in (*MAPS, owned, *(("unrelated.txt",) if unrelated else ())):
                (root / path).write_text("next\n")
            git("add", "--", *MAPS, owned, "unrelated.txt")
            git("commit", "-m", "next divergence")
            old = git("rev-parse", "HEAD")
            # All fetch/push operations remain within this temporary directory.
            git("init", "--bare", str(root / "origin.git"))
            git("remote", "add", "origin", str(root / "origin.git"))
            git("push", "origin", "testing", "next")
            result = subprocess.run(["bash", "-e", "-c", SHELL],
                                    cwd=root, env=env, text=True, capture_output=True)
            if live_map or unrelated:
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                expected = "retired ownership map still exists" if live_map else "unrelated.txt"
                self.assertIn(expected, result.stdout)
                self.assertEqual(git("rev-parse", "HEAD"), old)
                self.assertEqual(git("rev-parse", "origin/next"), old)
            else:
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse(any((root / path).exists() for path in MAPS))
                self.assertEqual((root / owned).read_text(), "next\n")
                self.assertEqual((root / "unrelated.txt").read_text(), "base\n")
                self.assertEqual(git("rev-parse", "HEAD"), git("rev-parse", "origin/next"))

    def test_retires_obsolete_maps_while_preserving_next_overlay(self):
        self.check_sync()

    def test_refuses_to_drop_unrelated_divergence(self):
        self.check_sync(unrelated=True)

    def test_refuses_to_drop_maps_still_present_on_testing(self):
        self.check_sync(live_map=True)


if __name__ == "__main__":
    unittest.main()
