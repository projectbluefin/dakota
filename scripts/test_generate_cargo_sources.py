#!/usr/bin/env python3
"""Unit tests for files/scripts/generate_cargo_sources.py.

Covers generate_sources() (the emitted `sources:` preamble, the cargo2 build
args, registry package selection, checksum-less and git+ package skipping) and
the `__main__` CLI entry point (usage error, exit code, happy path).

The module imports the third-party `toml` package, which is not installed on
the CI runner that executes `just check-publish-workflow`. A stdlib-backed
shim is registered in sys.modules before the module is loaded so these tests
are hermetic and run everywhere, without changing what the module does.
"""

import importlib.util
import runpy
import sys
import tempfile
import tomllib
import types
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[1]
MODULE_PATH = REPOSITORY / "files" / "scripts" / "generate_cargo_sources.py"


def _install_toml_shim() -> None:
    """Provide `toml.load` on top of stdlib tomllib when toml is absent."""
    try:
        import toml  # noqa: F401
    except ModuleNotFoundError:
        shim = types.ModuleType("toml")
        shim.load = lambda handle: tomllib.loads(handle.read())
        shim.loads = tomllib.loads
        sys.modules["toml"] = shim


_install_toml_shim()


def _load_module():
    spec = importlib.util.spec_from_file_location("generate_cargo_sources", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


generate_cargo_sources = _load_module()

REGISTRY = "registry+https://github.com/rust-lang/crates.io-index"


def write_lock(text: str) -> str:
    handle = tempfile.NamedTemporaryFile("w", suffix=".lock", delete=False)
    handle.write(text)
    handle.close()
    return handle.name


def run_generate(text: str) -> str:
    path = write_lock(text)
    buffer = StringIO()
    with redirect_stdout(buffer):
        generate_cargo_sources.generate_sources(path)
    return buffer.getvalue()


class PreambleTests(unittest.TestCase):
    def test_emits_local_source_first(self) -> None:
        output = run_generate("")
        self.assertEqual(
            output.splitlines()[:4],
            [
                "sources:",
                "- kind: local",
                "  path: files/uutils-coreutils",
                "- kind: cargo2",
            ],
        )

    def test_emits_cargo2_build_args(self) -> None:
        output = run_generate("")
        self.assertIn("  build-args:\n", output)
        self.assertIn("    - --release\n", output)
        self.assertIn("    - --no-default-features\n", output)
        self.assertIn("    - --features\n", output)
        self.assertIn("    - feat_os_unix\n", output)
        self.assertIn("  ref:\n", output)

    def test_empty_lock_emits_no_registry_entries(self) -> None:
        self.assertNotIn("kind: registry", run_generate(""))

    def test_lock_without_package_table_emits_no_entries(self) -> None:
        self.assertNotIn("kind: registry", run_generate('version = 4\n'))


class RegistryPackageTests(unittest.TestCase):
    def test_registry_package_is_emitted_with_name_version_sha(self) -> None:
        output = run_generate(
            f'[[package]]\nname = "libc"\nversion = "0.2.155"\n'
            f'source = "{REGISTRY}"\nchecksum = "abc123"\n'
        )
        self.assertIn(
            "  - kind: registry\n    name: libc\n    version: 0.2.155\n    sha: abc123\n",
            output,
        )

    def test_multiple_packages_preserve_lock_order(self) -> None:
        output = run_generate(
            f'[[package]]\nname = "aaa"\nversion = "1.0.0"\n'
            f'source = "{REGISTRY}"\nchecksum = "sha-aaa"\n\n'
            f'[[package]]\nname = "zzz"\nversion = "2.0.0"\n'
            f'source = "{REGISTRY}"\nchecksum = "sha-zzz"\n'
        )
        self.assertLess(output.index("name: aaa"), output.index("name: zzz"))

    def test_registry_package_without_checksum_is_skipped(self) -> None:
        output = run_generate(
            f'[[package]]\nname = "libc"\nversion = "0.2.155"\nsource = "{REGISTRY}"\n'
        )
        self.assertNotIn("name: libc", output)
        self.assertNotIn("kind: registry", output)

    def test_workspace_member_without_source_is_skipped(self) -> None:
        output = run_generate('[[package]]\nname = "coreutils"\nversion = "0.0.28"\n')
        self.assertNotIn("name: coreutils", output)

    def test_git_dependency_is_skipped(self) -> None:
        output = run_generate(
            '[[package]]\nname = "forked"\nversion = "0.1.0"\n'
            'source = "git+https://github.com/example/forked?rev=deadbeef#deadbeef"\n'
            'checksum = "sha-forked"\n'
        )
        self.assertNotIn("name: forked", output)

    def test_alternate_registry_is_skipped(self) -> None:
        output = run_generate(
            '[[package]]\nname = "internal"\nversion = "0.1.0"\n'
            'source = "sparse+https://example.invalid/index/"\nchecksum = "sha-internal"\n'
        )
        self.assertNotIn("name: internal", output)

    def test_mixed_lock_emits_only_registry_packages(self) -> None:
        output = run_generate(
            f'[[package]]\nname = "coreutils"\nversion = "0.0.28"\n\n'
            f'[[package]]\nname = "libc"\nversion = "0.2.155"\n'
            f'source = "{REGISTRY}"\nchecksum = "sha-libc"\n\n'
            f'[[package]]\nname = "forked"\nversion = "0.1.0"\n'
            f'source = "git+https://github.com/example/forked#deadbeef"\n'
        )
        self.assertEqual(output.count("kind: registry"), 1)
        self.assertIn("name: libc", output)


class CliTests(unittest.TestCase):
    def _run_main(self, argv: list[str]) -> tuple[int | None, str]:
        buffer = StringIO()
        status: int | None = None
        original = sys.argv
        sys.argv = argv
        try:
            with redirect_stdout(buffer):
                runpy.run_path(str(MODULE_PATH), run_name="__main__")
        except SystemExit as exc:
            status = exc.code
        finally:
            sys.argv = original
        return status, buffer.getvalue()

    def test_missing_argument_exits_nonzero_with_usage(self) -> None:
        status, output = self._run_main(["generate_cargo_sources.py"])
        self.assertEqual(status, 1)
        self.assertIn("Usage:", output)

    def test_lock_path_argument_generates_sources(self) -> None:
        path = write_lock(
            f'[[package]]\nname = "libc"\nversion = "0.2.155"\n'
            f'source = "{REGISTRY}"\nchecksum = "sha-libc"\n'
        )
        status, output = self._run_main(["generate_cargo_sources.py", path])
        self.assertIsNone(status)
        self.assertTrue(output.startswith("sources:\n"))
        self.assertIn("name: libc", output)

    def test_extra_arguments_are_ignored(self) -> None:
        path = write_lock("")
        status, output = self._run_main(["generate_cargo_sources.py", path, "--unused"])
        self.assertIsNone(status)
        self.assertIn("sources:", output)


if __name__ == "__main__":
    unittest.main()
