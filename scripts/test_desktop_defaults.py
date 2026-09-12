#!/usr/bin/env python3
"""Regression coverage for shipped desktop defaults and the preinstall probe."""

import ast
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CONDITION = ROOT / "files/service-overrides/flatpak-preinstall.service.d/condition-check.conf"
EXTENSIONS = ROOT / "elements/bluefin/shell-extensions/disable-ext-validator.bst"


class FlatpakPreinstallTests(unittest.TestCase):
    def run_condition(self, status: int | None) -> tuple[int, list[str]]:
        # Execute the actual unit's condition, not a copy of its implementation.
        commands = [
            line.split("=", 1)[1]
            for line in CONDITION.read_text().splitlines()
            if line.startswith("ExecCondition=")
        ]
        self.assertEqual(len(commands), 1)
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            log = temp / "arguments"
            if status is not None:
                binary = temp / "flatpak"
                binary.write_text(
                    '#!/bin/sh\n'
                    'printf "%s\\n" "$@" > "$PROBE_LOG"\n'
                    '[ "$#" -eq 2 ] && [ "$1" = preinstall ] && '
                    '[ "$2" = --help ] || exit 99\n'
                    # Successful help need not mention an English command name.
                    'printf "Aide disponible\\n"\n'
                    'exit "$PROBE_STATUS"\n'
                )
                binary.chmod(0o755)
            result = subprocess.run(
                shlex.split(commands[0]),
                env={
                    **os.environ,
                    "PATH": str(temp),
                    "PROBE_LOG": str(log),
                    "PROBE_STATUS": str(status),
                },
                capture_output=True,
                text=True,
                check=False,
                timeout=10,
            )
            arguments = log.read_text().splitlines() if log.exists() else []
        return result.returncode, arguments

    def test_supported_preinstall_is_not_skipped(self) -> None:
        status, arguments = self.run_condition(0)
        self.assertEqual(status, 0)
        self.assertEqual(arguments, ["preinstall", "--help"])

    def test_older_flatpak_skips_without_installing(self) -> None:
        status, arguments = self.run_condition(1)
        self.assertEqual(status, 1)
        self.assertEqual(arguments, ["preinstall", "--help"])

    def test_missing_flatpak_does_not_pass(self) -> None:
        status, arguments = self.run_condition(None)
        self.assertNotEqual(status, 0)
        self.assertEqual(arguments, [])

    def test_probe_error_is_not_mistaken_for_success(self) -> None:
        status, _ = self.run_condition(255)
        self.assertEqual(status, 255)


class DesktopDefaultsTests(unittest.TestCase):
    def enabled_extensions(self) -> list[str]:
        matches = re.findall(r"^\s*enabled-extensions=(\[.*\])$", EXTENSIONS.read_text(), re.M)
        self.assertEqual(len(matches), 1)
        return ast.literal_eval(matches[0])

    def test_personal_integrations_are_opt_in_with_backends_shipped(self) -> None:
        enabled = self.enabled_extensions()
        for uuid in (
            "syncthing-toggle@rehhouari.github.com",
            "syncthing-toggle@projectbluefin.io",
            "tailscale-gnome-qs@tailscale-qs.github.io",
            "copyous@boerdereinar.dev",
            "quick-settings-audio-panel@rayzeq.github.io",
            "quicksettings-audio-devices-hider@marcinjahn.com",
            "quicksettings-audio-devices-renamer@marcinjahn.com",
            "power-status-color@local",
        ):
            self.assertNotIn(uuid, enabled)
        self.assertIn("bluefin/syncthing.bst", (ROOT / "elements/bluefin/shell-extensions/syncthing-toggle.bst").read_text())
        self.assertIn("bluefin/tailscale-setup.bst", (ROOT / "elements/bluefin/shell-extensions/tailscale-qs.bst").read_text())
        # Native backends and interactive authorization ship with their controls.
        stack = (ROOT / "elements/bluefin/gnome-shell-extensions.bst").read_text()
        self.assertIn("bluefin/shell-extensions/syncthing-toggle.bst", stack)
        self.assertIn("bluefin/shell-extensions/tailscale-qs.bst", stack)
        self.assertIn("bluefin/tailscale.bst", (ROOT / "elements/bluefin/deps.bst").read_text())

    def test_budslink_and_supported_tiling_remain_enabled(self) -> None:
        enabled = self.enabled_extensions()
        self.assertIn("BudsLink-Companion@maniacx.github.com", enabled)
        self.assertIn("tilingshell@ferrarodomenico.com", enabled)
        self.assertIn("fuzzy-application-search@mkhl.codeberg.page", enabled)
        self.assertEqual(len(enabled), len(set(enabled)))
        self.assertNotIn("dakota-desktop-extensions", EXTENSIONS.read_text())
        self.assertFalse((ROOT / "files/desktop-integration").exists())

    def test_vicinae_package_and_keyboard_override_are_removed(self) -> None:
        self.assertFalse((ROOT / "elements/bluefin/vicinae.bst").exists())
        self.assertNotIn("vicinae", (ROOT / "elements/bluefin/deps.bst").read_text())
        keybindings = (ROOT / "files/dconf/06-dakota-keybindings").read_text()
        self.assertNotIn("vicinae", keybindings.lower())
        self.assertNotIn("switch-input-source=", keybindings)
        self.assertIn("command='/usr/bin/xdg-terminal-exec'", keybindings)


@unittest.skipUnless(shutil.which("jq"), "jq is required to exercise the BST metadata guard")
class TilingCompatibilityTests(unittest.TestCase):
    def check_metadata(
        self, versions: list[str], uuid: str = "tilingshell@ferrarodomenico.com"
    ) -> int:
        element = ROOT / "elements/bluefin/shell-extensions/tilingshell.bst"
        commands = [
            line.strip() for line in element.read_text().splitlines()
            if line.strip().startswith("jq -e ")
        ]
        self.assertEqual(len(commands), 1)
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / "metadata.json").write_text(
                json.dumps({"uuid": uuid, "shell-version": versions})
            )
            result = subprocess.run(
                ["/bin/sh", "-c", commands[0]],
                cwd=directory,
                capture_output=True,
                text=True,
                check=False,
                timeout=10,
            )
        return result.returncode

    def test_shell_50_package_is_accepted(self) -> None:
        self.assertEqual(self.check_metadata(["45", "46", "47", "48", "49", "50"]), 0)

    def test_old_shell_49_package_is_rejected(self) -> None:
        self.assertNotEqual(self.check_metadata(["45", "46", "47", "48", "49"]), 0)

    def test_wrong_extension_is_rejected(self) -> None:
        self.assertNotEqual(self.check_metadata(["50"], uuid="wrong@example.com"), 0)


if __name__ == "__main__":
    unittest.main()
