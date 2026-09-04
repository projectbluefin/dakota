#!/usr/bin/env python3
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[1]
CHECKER = REPOSITORY / "scripts" / "check_arch_axis.py"

# Everything the checker reads. Copied per-test so a mutation never touches
# the real tree.
WORKSPACE_PATHS = ("project.conf", "include", "elements")


class CheckArchAxisTests(unittest.TestCase):
    def run_checker(self, workspace: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(CHECKER)],
            cwd=workspace,
            text=True,
            capture_output=True,
            check=False,
        )

    def copy_workspace(self, workspace: Path) -> None:
        for relative in WORKSPACE_PATHS:
            source = REPOSITORY / relative
            destination = workspace / relative
            if source.is_dir():
                shutil.copytree(source, destination)
            else:
                shutil.copy(source, destination)

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
        self.assertIn("arch axis checks passed", result.stdout)

    def test_rejects_undeclared_arch_in_project_conf_switch(self) -> None:
        result = self.mutate(
            "project.conf",
            '    - arch == "aarch64":\n        go-arch: "arm64"\n',
            '    - arch == "aarch64":\n        go-arch: "arm64"\n'
            '    - arch == "ppc64le":\n        go-arch: "ppc64le"\n',
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("ppc64le", result.stderr)
        self.assertIn("can never be selected", result.stderr)

    def test_rejects_undeclared_arch_in_junction_options(self) -> None:
        result = self.mutate(
            "elements/freedesktop-sdk.bst",
            "    - arch == 'aarch64':\n        bootstrap_build_arch: 'aarch64'\n",
            "    - arch == 'aarch64':\n        bootstrap_build_arch: 'aarch64'\n"
            '    - arch == "riscv64":\n        bootstrap_build_arch: "x86_64"\n',
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("elements/freedesktop-sdk.bst", result.stderr)
        self.assertIn("riscv64", result.stderr)

    def test_rejects_undeclared_arch_in_element_conditional(self) -> None:
        result = self.mutate(
            "elements/core/linux-ogc.bst",
            '  - arch == "aarch64":\n      kernel_arch: arm64\n',
            '  - arch == "aarch64":\n      kernel_arch: arm64\n'
            '  - arch == "riscv64":\n      kernel_arch: riscv\n',
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("elements/core/linux-ogc.bst", result.stderr)
        self.assertIn("riscv64", result.stderr)

    def test_rejects_undeclared_arch_in_list_membership(self) -> None:
        result = self.mutate(
            "elements/core/linux-ogc.bst",
            '  - arch == "aarch64":\n      install-commands:',
            '  - arch in ["aarch64", "riscv64"]:\n      install-commands:',
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("riscv64", result.stderr)

    def test_ignores_arch_comparisons_inside_embedded_scripts(self) -> None:
        # `arch != "NATIVE"` appears inside an awk fragment in
        # elements/bluefin-nvidia/nvidia-drivers.bst. It is not an option
        # conditional and must not be read as one.
        result = self.run_checker(REPOSITORY)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("NATIVE", result.stderr)

    def test_rejects_declared_arch_with_no_variables_branch(self) -> None:
        result = self.mutate(
            "project.conf",
            "      - aarch64\n      - x86_64\n",
            "      - aarch64\n      - x86_64\n      - ppc64le\n",
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("no branch for declared arch 'ppc64le'", result.stderr)

    def test_rejects_variable_defined_on_only_some_arch_branches(self) -> None:
        result = self.mutate(
            "project.conf",
            '    - arch == "x86_64":\n        go-arch: "amd64"\n',
            '    - arch == "x86_64":\n        go-arch: "amd64"\n        gcc_arch: "x86-64"\n',
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("branch 'aarch64' does not define gcc_arch", result.stderr)

    def test_rejects_duplicate_arch_branch(self) -> None:
        result = self.mutate(
            "project.conf",
            '    - arch == "aarch64":\n        go-arch: "arm64"\n',
            '    - arch == "aarch64":\n        go-arch: "arm64"\n'
            '    - arch == "aarch64":\n        go-arch: "arm64"\n',
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("more than once", result.stderr)

    def test_reports_missing_arch_option(self) -> None:
        result = self.mutate(
            "project.conf",
            "  arch:\n    type: arch\n",
            "  cpu:\n    type: arch\n",
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("declares no `arch:` option", result.stderr)


if __name__ == "__main__":
    unittest.main()
