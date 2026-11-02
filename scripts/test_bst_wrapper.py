"""Offline checks that the BST wrapper preserves project CPU defaults and overrides."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("just"), "requires just")
class BstWrapperTests(unittest.TestCase):
    def run_wrapper(self, **overrides):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copy2(ROOT / "Justfile", root / "Justfile")
            podman = root / "podman"
            podman.write_text(
                "#!/usr/bin/env python3\n"
                "import json, sys\n"
                "print(json.dumps(sys.argv[1:]))\n"
            )
            podman.chmod(0o755)
            env = {
                key: value for key, value in os.environ.items()
                if not key.startswith(("BST_", "BUILD_"))
            }
            env.update(HOME=str(root), PATH=f"{root}:{env['PATH']}", **overrides)
            result = subprocess.run(
                ["just", "bst", "show", "oci/bluefin.bst"],
                cwd=root, env=env, capture_output=True, text=True,
                check=True, timeout=15,
            )
            argv = json.loads(result.stdout)
            # Only inspect the command passed to bst, not Podman's own options.
            return argv[argv.index("--") + 1:]

    def test_default_uses_project_cpu_baseline(self):
        self.assertEqual(self.run_wrapper(), [
            "--no-interactive", "-o", "gaming", "false",
            "-o", "secure_boot_signing", "false", "show", "oci/bluefin.bst",
        ])

    def test_explicit_cpu_override_is_preserved(self):
        for option in ("-o", "--option"):
            for value in ("true", "false"):
                with self.subTest(option=option, value=value):
                    args = self.run_wrapper(BST_FLAGS=f"{option} x86_64_v3 {value}")
                    self.assertEqual(args[:3], [option, "x86_64_v3", value])
                    self.assertEqual(args.count("x86_64_v3"), 1)

    def test_arm_and_ci_config_are_preserved_without_cpu_override(self):
        args = self.run_wrapper(
            BST_FLAGS="--config /src/buildstream-ci.conf --option arch aarch64"
        )
        self.assertEqual(args[:5], [
            "--config", "/src/buildstream-ci.conf", "--option", "arch", "aarch64",
        ])
        self.assertNotIn("x86_64_v3", args)

    def test_full_override_replaces_wrapper_defaults(self):
        self.assertEqual(self.run_wrapper(
            BST_FLAGS="-o x86_64_v3 true",
            BST_FLAGS_OVERRIDE="--option x86_64_v3 false",
        ), ["--option", "x86_64_v3", "false", "show", "oci/bluefin.bst"])

    def test_gaming_and_signing_still_propagate(self):
        self.assertEqual(self.run_wrapper(
            BUILD_GAMING="true", BUILD_SECURE_BOOT_SIGNING="true",
        ), [
            "--no-interactive", "-o", "gaming", "true",
            "-o", "secure_boot_signing", "true", "show", "oci/bluefin.bst",
        ])


if __name__ == "__main__":
    unittest.main()
