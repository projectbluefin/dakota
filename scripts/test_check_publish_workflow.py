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

    def test_rejects_unterminated_composite_action_shell(self) -> None:
        result = self.mutate(
            ".github/actions/generate-bst-ci-config/action.yml",
            "        set -euo pipefail\n",
            "        if true; then\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_missing_remote_execution_block(self) -> None:
        result = self.mutate(
            ".github/actions/generate-bst-ci-config/action.yml",
            "        remote-execution:\n",
            "        disabled-executor:\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_serial_build_matrix(self) -> None:
        result = self.mutate(
            ".github/workflows/build.yml",
            "      max-parallel: 4\n",
            "      max-parallel: 1\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_explicit_artifact_pull(self) -> None:
        result = self.mutate(
            ".github/workflows/build.yml",
            "      - name: Count elements for progress tracking\n",
            "      - name: Pull prebuilt artifacts from remote CAS\n"
            "        run: true\n\n"
            "      - name: Count elements for progress tracking\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_remote_publish_export(self) -> None:
        result = self.mutate(
            ".github/workflows/publish.yml",
            "          enable-remote-execution: 'false'\n",
            "          enable-remote-execution: 'true'\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
