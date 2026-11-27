"""Unit tests verifying Incus elements, units, presets, and ujust recipes."""
import os
import re
import subprocess
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class IncusPackagingTests(unittest.TestCase):
    def test_incus_in_package_manifest(self):
        deps_bst = (REPO / "elements/bluefin/deps.bst").read_text()
        self.assertIn("bluefin/incus.bst", deps_bst)

    def test_element_files_exist(self):
        expected_elements = [
            REPO / "elements/bluefin/incus.bst",
            REPO / "elements/bluefin/incus-deps/libuv.bst",
            REPO / "elements/bluefin/incus-deps/raft.bst",
            REPO / "elements/bluefin/incus-deps/cowsql.bst",
            REPO / "elements/bluefin/incus-deps/lxc.bst",
            REPO / "elements/bluefin/incus-deps/lxcfs.bst",
        ]
        for element in expected_elements:
            with self.subTest(element=element.name):
                self.assertTrue(element.is_file(), f"missing element {element}")

    def test_incus_support_files_exist(self):
        expected_files = [
            REPO / "files/incus/80-incus.preset",
            REPO / "files/incus/default-incus",
            REPO / "files/incus/incus-modules.conf",
            REPO / "files/incus/incus-startup.service",
            REPO / "files/incus/incus-sysusers.conf",
            REPO / "files/incus/incus-tmpfiles.conf",
            REPO / "files/incus/incus-user.service",
            REPO / "files/incus/incus-user.socket",
            REPO / "files/incus/incus.service",
            REPO / "files/incus/incus.socket",
        ]
        for path in expected_files:
            with self.subTest(file=path.name):
                self.assertTrue(path.is_file(), f"missing support file {path}")

    def test_incus_element_offline_and_subid_integration(self):
        content = (REPO / "elements/bluefin/incus.bst").read_text()
        self.assertIn("core/sandbox-tools.bst", content)
        self.assertIn("-mod=vendor", content)
        self.assertIn("-trimpath", content)
        self.assertIn("-buildvcs=false", content)
        self.assertIn("integration-commands:", content)
        self.assertIn("root:1000000:1000000000", content)
        self.assertNotIn("overlap-whitelist:", content)

    def test_systemd_preset_disables_services_by_default(self):
        preset = (REPO / "files/incus/80-incus.preset").read_text()
        self.assertIn("disable incus.service", preset)
        self.assertIn("disable incus.socket", preset)
        self.assertIn("disable incus-startup.service", preset)
        self.assertIn("disable incus-user.socket", preset)
        self.assertIn("disable lxcfs.service", preset)
        self.assertNotIn("enable", preset)

    def test_incus_service_deadlock_ordering_fix(self):
        incus_service = (REPO / "files/incus/incus.service").read_text()
        self.assertNotIn("incus-startup.service", incus_service)
        self.assertIn("After=network-online.target incus.socket", incus_service)

    def test_no_just_recipes_needed(self):
        system_just = (REPO / "files/just-overrides/system.just").read_text()
        self.assertNotIn("incus-init:", system_just)
        self.assertNotIn("incus-status:", system_just)


if __name__ == "__main__":
    unittest.main()
