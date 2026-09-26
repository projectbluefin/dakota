#!/usr/bin/env python3
"""Offline libvirt packaging checks; never start daemons or change host policy."""

import ast
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]
ELEMENT = ROOT / "elements/bluefin/libvirt.bst"
# Keep coverage aligned with every management driver activated by the helper.
DRIVERS = next(
    ast.literal_eval(node.value)
    for node in ast.parse((ROOT / "files/just-overrides/devmode.py").read_text()).body
    if isinstance(node, ast.Assign)
    and any(isinstance(target, ast.Name) and target.id == "DRIVERS" for target in node.targets)
)
POLICIES = (
    "usr/share/polkit-1/actions/org.libvirt.unix.policy",
    "usr/share/polkit-1/actions/org.libvirt.api.policy",
    "usr/share/polkit-1/rules.d/50-libvirt.rules",
)


class LibvirtPackagingTests(unittest.TestCase):
    def test_polkit_is_explicit_not_auto_detected(self):
        flags = re.findall(r"^\s+(-Dpolkit=\S+)\s*$", ELEMENT.read_text(), re.M)
        self.assertEqual(flags, ["-Dpolkit=enabled"])

    def test_polkit_is_a_runtime_dependency(self):
        element = ELEMENT.read_text()
        runtime = re.findall(r"^(?:runtime-depends|depends):\n((?:- .*\n|#.*\n|\n)*)", element, re.M)
        self.assertIn(
            "- freedesktop-sdk.bst:components/polkit.bst",
            "".join(runtime).splitlines(),
        )

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for policy in POLICIES:
            self.put(policy, "policy fixture\n")
        for driver in DRIVERS:
            self.put(f"usr/lib/systemd/system/virt{driver}d.socket", "[Socket]\nSocketMode=0666\n")
            self.put(f"etc/libvirt/virt{driver}d.conf", '#auth_unix_rw = "polkit"\n')

    def put(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def check_install(self):
        # Execute the actual last install block, rather than a duplicate guard.
        blocks = re.findall(r"^    - \|\n((?:      .*\n|\n)+)", ELEMENT.read_text(), re.M)
        self.assertGreaterEqual(len(blocks), 2, "libvirt must check its installed PolicyKit outputs")
        command = textwrap.dedent(blocks[-1])
        for variable, value in {
            "install-root": str(self.root), "prefix": "/usr", "sysconfdir": "/etc",
        }.items():
            command = command.replace(f"%{{{variable}}}", value)
        result = subprocess.run(
            ["/bin/sh", "-ec", command], capture_output=True, text=True, timeout=10,
        )
        return result.returncode

    def test_polkit_enabled_install_is_accepted(self):
        self.assertEqual(self.check_install(), 0)

    def test_each_missing_policy_is_rejected(self):
        for policy in POLICIES:
            with self.subTest(policy=policy):
                (self.root / policy).unlink()
                self.assertNotEqual(self.check_install(), 0)
                self.put(policy, "policy fixture\n")

    def test_each_root_only_management_socket_is_rejected(self):
        for driver in DRIVERS:
            with self.subTest(driver=driver):
                path = f"usr/lib/systemd/system/virt{driver}d.socket"
                self.put(path, "[Socket]\nSocketMode=0600\n")
                self.assertNotEqual(self.check_install(), 0)
                self.put(path, "[Socket]\nSocketMode=0666\n")

    def test_each_unauthenticated_management_default_is_rejected(self):
        for driver in DRIVERS:
            with self.subTest(driver=driver):
                path = f"etc/libvirt/virt{driver}d.conf"
                self.put(path, '#auth_unix_rw = "none"\n')
                self.assertNotEqual(self.check_install(), 0)
                self.put(path, '#auth_unix_rw = "polkit"\n')


if __name__ == "__main__":
    unittest.main()
