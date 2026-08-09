#!/usr/bin/env python3
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[1]
CHECKER = REPOSITORY / "scripts" / "check_publish_workflow.py"


class CheckPublishWorkflowTests(unittest.TestCase):
    def run_checker(self, workspace: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, CHECKER],
            cwd=workspace,
            text=True,
            capture_output=True,
            check=False,
        )

    def copy_workspace(self, workspace: Path) -> None:
        shutil.copytree(REPOSITORY / ".github", workspace / ".github")
        shutil.copytree(REPOSITORY / "files" / "bootc-install", workspace / "files" / "bootc-install")

    def mutate(self, relative_path: str, old: str, new: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as tempdir:
            workspace = Path(tempdir)
            self.copy_workspace(workspace)
            path = workspace / relative_path
            original = path.read_text()
            self.assertIn(old, original)
            path.write_text(original.replace(old, new, 1))
            return self.run_checker(workspace)

    def test_current_configuration_passes(self) -> None:
        result = self.run_checker(REPOSITORY)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_missing_wipe_flag(self) -> None:
        result = self.mutate(
            ".github/workflows/publish.yml",
            "            --wipe \\\n",
            "",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_generic_image_flag(self) -> None:
        result = self.mutate(
            ".github/workflows/publish.yml",
            "            --wipe \\\n",
            "            --wipe \\\n            --generic-image \\\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_bootloader_drift(self) -> None:
        result = self.mutate(
            "files/bootc-install/00-defaults.toml",
            'bootloader = "systemd"',
            'bootloader = "none"',
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_sbom_continue_drift(self) -> None:
        result = self.mutate(
            ".github/workflows/publish.yml",
            "  publish-sbom:\n",
            "  publish-sbom-disabled:\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
