#!/usr/bin/env python3
"""Regression coverage for shipped desktop defaults and the preinstall probe."""

import ast
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import stat
import subprocess
import tempfile
import unittest
from xml.etree import ElementTree


ROOT = Path(__file__).resolve().parents[1]
CONDITION = ROOT / "files/service-overrides/flatpak-preinstall.service.d/condition-check.conf"
EXTENSIONS = ROOT / "elements/bluefin/shell-extensions/disable-ext-validator.bst"
SYNCTHING_DEFAULTS = ROOT / "elements/bluefin/syncthing-defaults.bst"
SYNCTHING_FILES = ROOT / "files/syncthing-defaults"


def install_script(element: Path, install_root: Path) -> str:
    """An element's install-commands as a runnable shell script.

    BuildStream stages the element's sources as the working directory and then
    runs these commands, so running them is the only faithful way to observe
    what actually lands in the image.
    """
    lines = element.read_text().splitlines()
    body = []
    for line in lines[lines.index("  install-commands:") + 1:]:
        if line and not line.startswith("  "):
            break
        body.append(re.sub(r"^  - \|?", "", line))
    return (
        "\n".join(body)
        .replace("%{install-root}", str(install_root))
        # BuildStream expands variables before running the commands; the ones
        # these elements use must be expanded here too or the staged tree ends
        # up with literal "%{datadir}" directories.
        .replace("%{datadir}", "/usr/share")
        .replace("%{install-extra}", ":")
    )


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


class SyncthingDefaultsTests(unittest.TestCase):
    """Syncthing 2 has no automatic default folder, so the image supplies one."""

    @classmethod
    def setUpClass(cls) -> None:
        cls._staging = tempfile.TemporaryDirectory()
        root = Path(cls._staging.name)
        subprocess.run(
            ["sh", "-e", "-c", install_script(SYNCTHING_DEFAULTS, root)],
            cwd=SYNCTHING_FILES,
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        )
        cls.root = root
        cls.skel = root / "etc/skel"

    @classmethod
    def tearDownClass(cls) -> None:
        cls._staging.cleanup()

    def folders(self) -> list[ElementTree.Element]:
        return ElementTree.parse(SYNCTHING_FILES / "config.xml").getroot().findall("folder")

    def test_shipped_modes_are_repaired_in_the_image_and_at_login(self) -> None:
        """Modes cannot come from the artifact, so both layers must be present.

        BuildStream stores artifacts in CAS, which records only an executable
        bit. `bst artifact checkout bluefin/syncthing-defaults.bst` yields
        config.xml as 0644 and every directory as 0755, not the 0600/0700 the
        element installs; on a real image those modes reached /etc/skel and
        useradd copied them into new accounts. A second local user could then
        write into another user's synced folders, which Syncthing replicates to
        every paired device.

        The image assembly fixes the shipped skel, closing the window between
        account creation and first login; the tmpfiles rules repair a live
        account afterwards.
        """
        # Modes must be applied at final image assembly: element- and
        # stack-level integration commands both run before a CAS boundary that
        # drops them. Measured on a real build, neither reached /etc/skel
        # through the syncthing-toggle -> bluefin-stack -> compose indirection,
        # which is why the stack does this where dakota already fixes the image.
        images = {
            name: (ROOT / name).read_text()
            for name in ("elements/oci/bluefin.bst", "elements/oci/bluefin-nvidia.bst")
        }
        self.assertNotIn(
            "integration-commands",
            SYNCTHING_DEFAULTS.read_text(),
            "element-level integration commands never execute for this element",
        )
        private = {
            "/etc/skel/.local/state/syncthing": "0700",
            "/etc/skel/.local/state/syncthing/config.xml": "0600",
        }
        shared = [
            "/etc/skel/.config",
            "/etc/skel/.local",
            "/etc/skel/.local/state",
            "/etc/skel/Documents",
            "/etc/skel/Music",
            "/etc/skel/Pictures",
            "/etc/skel/Videos",
        ]
        # Every image dakota publishes needs the fix: the nvidia variant is a
        # separate compose, so asserting over both files at once would pass
        # with the modes applied to only one of them.
        for name, image in images.items():
            for path, mode in private.items():
                self.assertRegex(
                    image,
                    rf"chmod {mode}[^\n]*/layer{re.escape(path)}",
                    f"{name}: {path} is not chmodded to {mode} before build-oci",
                )
            for path in shared:
                self.assertRegex(
                    image,
                    rf"chmod 0755[^\n]*/layer{re.escape(path)}\b",
                    f"{name}: {path} ships world-writable unless image assembly chmods it",
                )

        rule = self.root / "usr/share/user-tmpfiles.d/50-dakota-syncthing.conf"
        self.assertTrue(rule.is_file(), "no user-tmpfiles rule ships with the element")
        by_path = {
            fields[1]: fields
            for fields in (
                line.split()
                for line in rule.read_text().splitlines()
                if line.strip() and not line.startswith("#")
            )
        }
        # Only the two Syncthing-owned paths may carry runtime rules. Rules for
        # %h/.config, %h/.local or the XDG directories would match every
        # existing account, overwriting modes the user chose — widening a
        # deliberately private ~/Documents from 0700 to 0755, for example.
        expected = {
            "%h/.local/state/syncthing": "0700",
            "%h/.local/state/syncthing/config.xml": "0600",
        }
        self.assertEqual(
            sorted(by_path),
            sorted(expected),
            "runtime rules must not reach beyond the Syncthing state directory",
        )
        for path, mode in expected.items():
            fields = by_path[path]
            # `z` adjusts an existing path and never creates one, so it cannot
            # seed a config into an account that never had one.
            self.assertEqual(
                fields[0], "z", f"{path} uses '{fields[0]}', which can create or truncate"
            )
            self.assertEqual(fields[2], mode, f"{path} sets {fields[2]}, expected {mode}")

    def test_every_shipped_folder_syncs_without_being_unpaused(self) -> None:
        folders = self.folders()
        self.assertEqual(
            sorted(folder.get("id") for folder in folders),
            ["documents", "music", "pictures", "videos"],
        )
        # Folder ids are the cross-device join key; a paused folder silently
        # never replicates, which is indistinguishable from a broken pairing.
        for folder in folders:
            self.assertEqual(folder.findtext("paused"), "false", folder.get("id"))

    def test_baked_config_carries_no_device_identity(self) -> None:
        # Certificates, keys and the device ID are per-machine and are created
        # on first run. Shipping any of them in the image would give every
        # installation the same identity.
        config = SYNCTHING_FILES / "config.xml"
        root = ElementTree.parse(config).getroot()
        self.assertEqual(root.findall("device"), [])
        for folder in self.folders():
            self.assertEqual(folder.findall("device"), [])
        text = config.read_text()
        self.assertNotRegex(text, r"[A-Z2-7]{7}(-[A-Z2-7]{7}){3}")
        self.assertNotRegex(text, r"-----BEGIN [A-Z ]+-----")
        # Nothing but the template and the two config files may ship here; a
        # stray cert.pem or key.pem would give every installation one identity.
        self.assertEqual(
            sorted(path.name for path in SYNCTHING_FILES.iterdir()),
            ["config.xml", "syncthing-defaults.conf", "user-dirs.dirs"],
        )

    def test_configured_xdg_directories_ship_with_their_names(self) -> None:
        # xdg-user-dirs-update reassigns a configured directory to $HOME when
        # the directory is missing, which would hand Syncthing the whole home
        # directory, its own key.pem included. The untranslated names and the
        # directories themselves must ship together or that happens in any
        # locale the user picks.
        user_dirs = (self.skel / ".config/user-dirs.dirs").read_text()
        configured = re.findall(r'^XDG_\w+_DIR="\$HOME/([^"/]+)"$', user_dirs, re.M)
        self.assertEqual(sorted(configured), ["Documents", "Music", "Pictures", "Videos"])
        for name in configured:
            self.assertTrue((self.skel / name).is_dir(), f"/etc/skel/{name} is not shipped")
        # And Syncthing must point at exactly those directories, never at ~.
        self.assertEqual(
            sorted(folder.get("path") for folder in self.folders()),
            sorted(f"~/{name}" for name in configured),
        )

    def test_web_gui_stays_on_loopback_and_on_the_port_the_toggle_opens(self) -> None:
        """The GUI administers every shared folder, so it must not leave the host.

        It ships with no username or password: `sendBasicAuthPrompt` is off and
        Syncthing only generates an apikey on first run. Bound to anything but
        loopback, any machine on the network could add its own device to every
        folder. The quick-settings toggle's "Open Web GUI" entry opens
        `http://127.0.0.1:<port>` with `port` defaulting to 8384
        (bluefin-bling's GSettings key), so this address has to match exactly —
        including the IPv4 form, since a `localhost` client may try ::1 first.
        """
        gui = ElementTree.parse(SYNCTHING_FILES / "config.xml").getroot().find("gui")
        # Shipping no <gui> at all would leave every setting below to upstream
        # defaults, which this project pins deliberately.
        self.assertIsNotNone(gui, "the config ships no <gui> element")
        self.assertEqual(gui.findtext("address"), "127.0.0.1:8384")
        # Both are child elements in Syncthing's config schema, not attributes,
        # and either one turns the unauthenticated GUI into a remote entry
        # point: insecureAdminAccess serves it on every bound address,
        # insecureSkipHostcheck drops the DNS-rebinding guard.
        for name in ("insecureAdminAccess", "insecureSkipHostcheck"):
            self.assertEqual(
                gui.findtext(name, "false").strip().lower(),
                "false",
                f"<{name}> exposes the GUI beyond this machine",
            )

    def test_toggle_ships_the_defaults_it_exposes(self) -> None:
        toggle = (ROOT / "elements/bluefin/shell-extensions/syncthing-toggle.bst").read_text()
        self.assertIn("- bluefin/syncthing-defaults.bst", toggle)


if __name__ == "__main__":
    unittest.main()
