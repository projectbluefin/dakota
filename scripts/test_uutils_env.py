#!/usr/bin/env python3
"""Exercise the packaged env applet after a launcher canonicalizes its path."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]
ELEMENT = ROOT / "elements/bluefin/uutils-coreutils.bst"
BINARY = os.environ.get("UUTILS_COREUTILS") or shutil.which("uutils-coreutils")


@unittest.skipUnless(BINARY, "requires uutils-coreutils or UUTILS_COREUTILS")
class UutilsEnvPackagingTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="dakota-uutils-env-")
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)
        self.root = self.work / "install"
        binary = self.work / "target/release/coreutils"
        binary.parent.mkdir(parents=True)
        shutil.copy2(BINARY, binary)

        # Execute the element's install commands, not a second implementation.
        install = ELEMENT.read_text().split("  install-commands:\n", 1)[1].split("\npublic:", 1)[0]
        commands = re.findall(r"^  - (?:\|\n((?:    .*\n|\n)+)|([^\n]+)\n)", install, re.M)
        for block, scalar in commands:
            command = textwrap.dedent(block) if block else scalar
            subprocess.run(
                ["/bin/sh", "-ec", command.replace("%{install-root}", str(self.root))],
                cwd=self.work,
                check=True,
                capture_output=True,
                text=True,
                timeout=30,
            )

    def test_canonicalized_public_entry_points_run_env_not_multicall(self):
        for name in ("env", "uutils-env"):
            with self.subTest(entry_point=name):
                public = self.root / "usr/bin" / name
                result = subprocess.run(
                    [f"/usr/bin/{name}", "-i", "DAKOTA_ENV_PROBE=canonical"],
                    executable=public.resolve(strict=True),
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "DAKOTA_ENV_PROBE=canonical\n")


if __name__ == "__main__":
    unittest.main()
