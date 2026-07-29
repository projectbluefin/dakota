#!/usr/bin/env python3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[1]
CHECKER = REPOSITORY / "scripts" / "check_docs.py"
SANDBOX_ROOT = REPOSITORY / ".cache" / "docs-check-tests"


class CheckDocsTests(unittest.TestCase):
    def run_checker(self, workspace: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, CHECKER],
            cwd=workspace,
            text=True,
            capture_output=True,
            check=False,
        )

    def write_workspace(self, workspace: Path, files: dict[str, str]) -> None:
        subprocess.run(["git", "init", "-q"], cwd=workspace, check=True)
        subprocess.run(["git", "config", "user.email", "docs-check@example.com"], cwd=workspace, check=True)
        subprocess.run(["git", "config", "user.name", "Docs Check"], cwd=workspace, check=True)
        for relative, content in files.items():
            path = workspace / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        subprocess.run(["git", "add", "."], cwd=workspace, check=True)

    def sandbox(self):
        SANDBOX_ROOT.mkdir(parents=True, exist_ok=True)
        return tempfile.TemporaryDirectory(dir=SANDBOX_ROOT)

    def test_rejects_broken_relative_link_outside_fenced_code_block(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            self.write_workspace(workspace, {"README.md": "[missing](docs/missing.md)\n"})

            result = self.run_checker(workspace)

            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("broken relative markdown link", result.stdout + result.stderr)

    def test_ignores_broken_relative_link_inside_fenced_code_block(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            self.write_workspace(
                workspace,
                {
                    "README.md": (
                        "```md\n"
                        "[missing](docs/missing.md)\n"
                        "```\n"
                    )
                },
            )

            result = self.run_checker(workspace)

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("docs contract check passed", result.stdout)

    def test_rejects_legacy_router_reference(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            self.write_workspace(workspace, {"README.md": "See docs/skills/README.md\n"})

            result = self.run_checker(workspace)

            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("legacy router path", result.stdout + result.stderr)

    def test_rejects_skill_without_frontmatter(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            self.write_workspace(workspace, {"docs/skills/example/SKILL.md": "# Example\n"})

            result = self.run_checker(workspace)

            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("frontmatter", result.stdout + result.stderr)

    def test_rejects_client_specific_instruction_string(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            self.write_workspace(
                workspace,
                {"README.md": "See .github/copilot-instructions.md for details.\n"},
            )

            result = self.run_checker(workspace)

            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("client-specific instruction string", result.stdout + result.stderr)

    def test_accepts_skill_module_at_line_budget_with_trailing_newline(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            lines = [
                "---",
                "name: Example",
                "description: Example skill",
                "---",
                "# Example",
                *["Body" for _ in range(395)],
            ]
            self.write_workspace(
                workspace,
                {"docs/skills/example/SKILL.md": "\n".join(lines) + "\n"},
            )

            result = self.run_checker(workspace)

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("docs contract check passed", result.stdout)

    def test_rejects_skill_module_over_line_budget(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            lines = [
                "---",
                "name: Example",
                "description: Example skill",
                "---",
                "# Example",
                *["Body" for _ in range(396)],
            ]
            self.write_workspace(
                workspace,
                {"docs/skills/example/SKILL.md": "\n".join(lines) + "\n"},
            )

            result = self.run_checker(workspace)

            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("exceeds size budget of 400 lines", result.stdout + result.stderr)

    def test_rejects_skill_module_over_byte_budget(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            body = "x" * 20_100
            self.write_workspace(
                workspace,
                {
                    "docs/skills/example/SKILL.md": (
                        "---\n"
                        "name: Example\n"
                        "description: Example skill\n"
                        "---\n"
                        "# Example\n"
                        f"{body}\n"
                    )
                },
            )

            result = self.run_checker(workspace)

            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("exceeds size budget of 20000 bytes", result.stdout + result.stderr)

    def test_rejects_nested_skill_module_path(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            self.write_workspace(
                workspace,
                {"docs/skills/example/nested/SKILL.md": "# Nested\n"},
            )

            result = self.run_checker(workspace)

            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn(
                "skill modules must live at docs/skills/<topic>/SKILL.md",
                result.stdout + result.stderr,
            )

    def test_accepts_canonical_skill_router(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            self.write_workspace(
                workspace,
                {"docs/skills/index.md": "# Skill index\n"},
            )

            result = self.run_checker(workspace)

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("docs contract check passed", result.stdout)

    def test_rejects_stale_planning_heading(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            self.write_workspace(
                workspace,
                {"README.md": "# Session Notes\n"},
            )

            result = self.run_checker(workspace)

            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("stale planning/history heading", result.stdout + result.stderr)

    def test_rejects_stale_planning_heading_at_any_level_but_ignores_fences(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            self.write_workspace(
                workspace,
                {
                    "README.md": (
                        "# Root\n"
                        "## TODO\n"
                        "```md\n"
                        "## TODO\n"
                        "```\n"
                    )
                },
            )

            result = self.run_checker(workspace)

            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(
                (result.stdout + result.stderr).count("stale planning/history heading"),
                1,
            )

    def test_ignores_superpowers_legacy_path_text(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            self.write_workspace(
                workspace,
                {
                    "docs/superpowers/specs/example.md": (
                        "See docs/skills/README.md and .github/copilot-instructions.md\n"
                    )
                },
            )

            result = self.run_checker(workspace)

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("docs contract check passed", result.stdout)

    def test_ignores_hive_policy_heading_comments(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            self.write_workspace(
                workspace,
                {
                    "files/hive/agent-policies/architect.md": (
                        "# Hive architect agent policy — dakota\n"
                        "#\n"
                        "# Comment line\n"
                        "# Another comment line\n"
                    )
                },
            )

            result = self.run_checker(workspace)

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("docs contract check passed", result.stdout)

    def test_accepts_stale_heading_in_hive_policy_file(self) -> None:
        with self.sandbox() as tempdir:
            workspace = Path(tempdir)
            self.write_workspace(
                workspace,
                {
                    "files/hive/agent-policies/reviewer.md": (
                        "# Notes\n"
                        "Policy details.\n"
                    )
                },
            )

            result = self.run_checker(workspace)

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("docs contract check passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
