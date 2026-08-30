#!/usr/bin/env python3
"""Unit tests for scripts/check_arch_axis.py."""

import importlib.util
from pathlib import Path
import sys
import tempfile
import textwrap
import unittest

SCRIPT = Path(__file__).resolve().parent / "check_arch_axis.py"
_spec = importlib.util.spec_from_file_location("check_arch_axis", SCRIPT)
check_arch_axis = importlib.util.module_from_spec(_spec)
sys.modules["check_arch_axis"] = check_arch_axis
_spec.loader.exec_module(check_arch_axis)

REPO_ROOT = SCRIPT.parent.parent

BASE_PROJECT_CONF = textwrap.dedent(
    """\
    name: bluefin
    min-version: 2.5
    element-path: elements

    options:
      arch:
        type: arch
        description: Machine architecture
        variable: arch
        values:
          - aarch64
          - x86_64
      x86_64_v3:
        type: bool
        description: Enable x86_64-v3
        default: false

    variables:
      branch: main
      (?):
        - arch == "x86_64":
            go-arch: "amd64"
        - arch == "aarch64":
            go-arch: "arm64"
    """
)


def write_project(tmpdir, project_conf=BASE_PROJECT_CONF, elements=None):
    root = Path(tmpdir)
    (root / "project.conf").write_text(project_conf, encoding="utf-8")
    (root / "elements").mkdir(exist_ok=True)
    for name, body in (elements or {}).items():
        path = root / "elements" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body, encoding="utf-8")
    return root


class DeclaredArchValuesTests(unittest.TestCase):
    def test_reads_values_in_order(self):
        self.assertEqual(
            check_arch_axis.declared_arch_values(BASE_PROJECT_CONF),
            ["aarch64", "x86_64"],
        )

    def test_ignores_a_later_unrelated_values_block(self):
        conf = BASE_PROJECT_CONF + textwrap.dedent(
            """
            other:
              values:
                - not-an-arch
            """
        )
        self.assertEqual(
            check_arch_axis.declared_arch_values(conf), ["aarch64", "x86_64"]
        )

    def test_strips_quotes_from_values(self):
        conf = BASE_PROJECT_CONF.replace("      - aarch64", '      - "aarch64"')
        self.assertEqual(
            check_arch_axis.declared_arch_values(conf), ["aarch64", "x86_64"]
        )

    def test_raises_when_the_declaration_is_absent(self):
        with self.assertRaises(ValueError):
            check_arch_axis.declared_arch_values("name: bluefin\n")


class VariablesArchBranchTests(unittest.TestCase):
    def test_collects_variable_names_per_branch(self):
        self.assertEqual(
            check_arch_axis.variables_arch_branches(BASE_PROJECT_CONF),
            {"x86_64": {"go-arch"}, "aarch64": {"go-arch"}},
        )

    def test_ignores_variables_outside_the_switch(self):
        branches = check_arch_axis.variables_arch_branches(BASE_PROJECT_CONF)
        for names in branches.values():
            self.assertNotIn("branch", names)

    def test_stops_at_the_next_top_level_key(self):
        conf = BASE_PROJECT_CONF + textwrap.dedent(
            """\
            sandbox:
              build-arch: "%{arch}"
            """
        )
        self.assertEqual(
            check_arch_axis.variables_arch_branches(conf),
            {"x86_64": {"go-arch"}, "aarch64": {"go-arch"}},
        )


class ConditionalScanTests(unittest.TestCase):
    def test_scans_elements_recursively(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = write_project(
                tmpdir,
                elements={"core/linux.bst": '(?):\n  - arch == "x86_64":\n      a: b\n'},
            )
            found = check_arch_axis.scan_conditionals(root)
            self.assertIn((Path("elements/core/linux.bst"), 2, "x86_64"), found)

    def test_accepts_single_and_double_quotes(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = write_project(
                tmpdir,
                elements={"a.bst": "(?):\n  - arch == 'aarch64':\n      a: b\n"},
            )
            values = [value for _, _, value in check_arch_axis.scan_conditionals(root)]
            self.assertIn("aarch64", values)

    def test_skips_commented_lines(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = write_project(
                tmpdir,
                elements={"a.bst": '# arch == "riscv64" was removed here\n'},
            )
            values = [value for _, _, value in check_arch_axis.scan_conditionals(root)]
            self.assertNotIn("riscv64", values)


class CheckTests(unittest.TestCase):
    def test_clean_project_passes(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = write_project(tmpdir)
            self.assertEqual(check_arch_axis.check(root), [])

    def test_flags_unreachable_conditional_in_an_element(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = write_project(
                tmpdir,
                elements={
                    "core/linux.bst": '(?):\n  - arch == "riscv64":\n      a: b\n'
                },
            )
            errors = check_arch_axis.check(root)
            self.assertEqual(len(errors), 1)
            self.assertIn("elements/core/linux.bst:2", errors[0])
            self.assertIn("riscv64", errors[0])

    def test_flags_unreachable_conditional_in_project_conf(self):
        conf = BASE_PROJECT_CONF + '    - arch == "ppc64le":\n        go-arch: "ppc64le"\n'
        with tempfile.TemporaryDirectory() as tmpdir:
            root = write_project(tmpdir, project_conf=conf)
            errors = check_arch_axis.check(root)
            self.assertTrue(any("ppc64le" in error for error in errors))

    def test_flags_variable_defined_on_only_one_arch(self):
        conf = BASE_PROJECT_CONF.replace(
            '    - arch == "x86_64":\n        go-arch: "amd64"',
            '    - arch == "x86_64":\n        go-arch: "amd64"\n'
            '        systemd-arch: "x86-64"',
        )
        with tempfile.TemporaryDirectory() as tmpdir:
            root = write_project(tmpdir, project_conf=conf)
            errors = check_arch_axis.check(root)
            self.assertEqual(len(errors), 1)
            self.assertIn("aarch64", errors[0])
            self.assertIn("systemd-arch", errors[0])

    def test_flags_declared_arch_with_no_variables_branch(self):
        conf = BASE_PROJECT_CONF.replace(
            "      - aarch64\n      - x86_64",
            "      - aarch64\n      - riscv64\n      - x86_64",
        )
        with tempfile.TemporaryDirectory() as tmpdir:
            root = write_project(tmpdir, project_conf=conf)
            errors = check_arch_axis.check(root)
            self.assertTrue(
                any("no branch for ['riscv64']" in error for error in errors), errors
            )

    def test_adding_an_arch_consistently_passes(self):
        conf = BASE_PROJECT_CONF.replace(
            "      - aarch64\n      - x86_64",
            "      - aarch64\n      - riscv64\n      - x86_64",
        ).replace(
            '    - arch == "aarch64":\n        go-arch: "arm64"',
            '    - arch == "aarch64":\n        go-arch: "arm64"\n'
            '    - arch == "riscv64":\n        go-arch: "riscv64"',
        )
        with tempfile.TemporaryDirectory() as tmpdir:
            root = write_project(tmpdir, project_conf=conf)
            self.assertEqual(check_arch_axis.check(root), [])


class RepositoryTests(unittest.TestCase):
    """The gate must pass against the real checkout."""

    def test_repository_arch_axis_is_clean(self):
        self.assertEqual(check_arch_axis.check(REPO_ROOT), [])

    def test_repository_declares_exactly_the_two_built_arches(self):
        conf = (REPO_ROOT / "project.conf").read_text(encoding="utf-8")
        self.assertEqual(
            check_arch_axis.declared_arch_values(conf), ["aarch64", "x86_64"]
        )

    def test_go_arch_is_defined_for_every_declared_arch(self):
        conf = (REPO_ROOT / "project.conf").read_text(encoding="utf-8")
        branches = check_arch_axis.variables_arch_branches(conf)
        for arch in check_arch_axis.declared_arch_values(conf):
            self.assertIn("go-arch", branches[arch])


if __name__ == "__main__":
    unittest.main()
