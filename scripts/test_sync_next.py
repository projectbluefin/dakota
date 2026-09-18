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
SHARED_KERNEL_CONFIG = "files/linux/dakota-config.sh"
KERNEL_OVERLAY = (
    "elements/core/linux-fdsdk.bst",
    "elements/core/linux-ogc.bst",
    "files/linux/config-utils.sh",
    "files/linux/fdsdk-config.sh",
    "files/linux-ogc/ogc.config.set",
    "files/linux-ogc/ogc.config.unset",
)


class SyncNextTests(unittest.TestCase):
    def check_sync(self, *, live_map=False, unrelated=False, kernel_updates=False,
                   shared_divergence=False):
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
            fixtures = (*MAPS, owned, "unrelated.txt", SHARED_KERNEL_CONFIG,
                        *KERNEL_OVERLAY)
            for path in fixtures:
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("base\n")
            git("add", "--", *fixtures)
            git("commit", "-m", "base")
            base = git("rev-parse", "HEAD")
            git("rm", "--", *(MAPS[1:] if live_map else MAPS))
            if kernel_updates:
                for path in (SHARED_KERNEL_CONFIG, *KERNEL_OVERLAY):
                    (root / path).write_text("testing\n")
                # New shared files must not be removed by a parent-directory restore.
                (root / "files/linux/shared-new.sh").write_text("testing\n")
                git("add", "--", "files/linux", *KERNEL_OVERLAY)
            git("commit", "-m", "testing updates")
            git("switch", "--no-track", "-c", "next", base)
            for path in (*MAPS, owned, *KERNEL_OVERLAY,
                         *(("unrelated.txt",) if unrelated else ()),
                         *((SHARED_KERNEL_CONFIG,) if shared_divergence else ())):
                (root / path).write_text("next\n")
            git("add", "--", *fixtures)
            git("commit", "-m", "next divergence")
            old = git("rev-parse", "HEAD")
            # All fetch/push operations remain within this temporary directory.
            git("init", "--bare", str(root / "origin.git"))
            git("remote", "add", "origin", str(root / "origin.git"))
            git("push", "origin", "testing", "next")
            result = subprocess.run(["bash", "-e", "-c", SHELL],
                                    cwd=root, env=env, text=True, capture_output=True)
            if live_map or unrelated or shared_divergence:
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                expected = ("retired ownership map still exists" if live_map else
                            SHARED_KERNEL_CONFIG if shared_divergence else "unrelated.txt")
                self.assertIn(expected, result.stdout)
                self.assertEqual(git("rev-parse", "HEAD"), old)
                self.assertEqual(git("rev-parse", "origin/next"), old)
            else:
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse(any((root / path).exists() for path in MAPS))
                self.assertEqual((root / owned).read_text(), "next\n")
                self.assertEqual((root / "unrelated.txt").read_text(), "base\n")
                for path in KERNEL_OVERLAY:
                    self.assertEqual((root / path).read_text(), "next\n", path)
                self.assertEqual((root / SHARED_KERNEL_CONFIG).read_text(),
                                 "testing\n" if kernel_updates else "base\n")
                if kernel_updates:
                    self.assertEqual((root / "files/linux/shared-new.sh").read_text(),
                                     "testing\n")
                self.assertEqual(git("rev-parse", "HEAD"), git("rev-parse", "origin/next"))

    def test_retires_obsolete_maps_while_preserving_next_overlay(self):
        self.check_sync()

    def test_refuses_to_drop_unrelated_divergence(self):
        self.check_sync(unrelated=True)

    def test_refuses_to_drop_maps_still_present_on_testing(self):
        self.check_sync(live_map=True)

    def test_shared_kernel_updates_flow_without_replacing_next_kernel_overlay(self):
        self.check_sync(kernel_updates=True)

    def test_refuses_unreconciled_next_changes_to_shared_kernel_config(self):
        self.check_sync(kernel_updates=True, shared_divergence=True)


if __name__ == "__main__":
    unittest.main()
