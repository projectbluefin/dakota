#!/usr/bin/env python3
"""Offline tests for the dakota-devmode Flatpak install path. No flatpak, polkit, or network."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "dakota_devmode_flatpak", REPO / "files" / "just-overrides" / "devmode.py"
)
devmode = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = devmode
SPEC.loader.exec_module(devmode)


class Tty(io.StringIO):
    def isatty(self) -> bool:
        return True


class FakeFlatpak:
    """Records argument vectors and answers `flatpak list` from fixed inventories."""

    def __init__(self, system=(), user=(), install_rc=0, remote_session=False):
        self.system = list(system)
        self.user = list(user)
        self.install_rc = install_rc
        self.remote_session = remote_session
        self.calls: list[tuple[str, ...]] = []

    def __call__(self, *args, capture=False, env=None):
        self.calls.append(args)
        stdout = ""
        rc = 0
        if args[:2] == ("flatpak", "list"):
            stdout = "\n".join(self.system if args[2] == "--system" else self.user)
            if stdout:
                stdout += "\n"
        elif args[:2] == ("flatpak", "install"):
            rc = self.install_rc
        elif args[0] == "loginctl":
            stdout = "yes\n" if self.remote_session else "no\n"
        return subprocess.CompletedProcess(args, rc, stdout if capture else None, None)

    @property
    def installs(self) -> list[tuple[str, ...]]:
        return [call for call in self.calls if call[:2] == ("flatpak", "install")]


class FlatpakInstallTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.enterContext(mock.patch.dict(os.environ))
        os.environ.pop("XDG_SESSION_ID", None)

    def brewfile(self, name: str, content: str) -> str:
        path = Path(self.work.name) / name
        path.write_text(content, encoding="utf-8")
        return str(path)

    def run_command(self, args, fake: FakeFlatpak, tty: bool = False):
        stdin = Tty() if tty else io.StringIO()
        stdout = Tty() if tty else io.StringIO()
        stderr = io.StringIO()
        with mock.patch.object(devmode, "run", fake), mock.patch.object(sys, "stdin", stdin), \
                contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            try:
                rc = devmode.flatpak_install_command(args)
            except devmode.SetupError as error:
                print(error, file=stderr)
                rc = 1
        return rc, stdout.getvalue(), stderr.getvalue()

    def test_brewfile_entries_skip_apps_installed_in_either_scope(self):
        path = self.brewfile(
            "dev.Brewfile",
            '# Comment line\nbrew "ripgrep"\nflatpak "org.example.One"\n'
            'flatpak "org.example.Two"   # trailing comment\n'
            'flatpak "org.example.Three"\nflatpak "org.example.Four"\n',
        )
        fake = FakeFlatpak(system=["org.example.Two"], user=["org.example.Four"])
        rc, out, err = self.run_command(["--file", path], fake)
        self.assertEqual(rc, 0, err)
        self.assertEqual(
            fake.installs,
            [("flatpak", "install", "--system", "--assumeyes", "flathub",
              "org.example.One", "org.example.Three")],
        )
        self.assertIn("org.example.Two is already installed", out)
        self.assertIn("org.example.Four is already installed", out)

    def test_remote_grouping_and_duplicates(self):
        path = self.brewfile(
            "remote.Brewfile",
            'flatpak "org.example.One"\nflatpak "org.example.Other", remote: "other"\n'
            'flatpak "org.example.One"\n',
        )
        fake = FakeFlatpak()
        rc, _, err = self.run_command(["--file=" + path, "org.example.One"], fake)
        self.assertEqual(rc, 0, err)
        self.assertEqual(
            fake.installs,
            [("flatpak", "install", "--system", "--assumeyes", "flathub", "org.example.One"),
             ("flatpak", "install", "--system", "--assumeyes", "other", "org.example.Other")],
        )

    def test_everything_installed_is_a_noop_success(self):
        fake = FakeFlatpak(system=["org.example.One"])
        rc, out, _ = self.run_command(["org.example.One"], fake)
        self.assertEqual(rc, 0)
        self.assertEqual(fake.installs, [])
        self.assertIn("already installed", out)

    def test_unsupported_brewfile_syntax_fails_closed(self):
        path = self.brewfile(
            "bad.Brewfile", 'flatpak "org.example.One", url: "https://example.invalid/repo"\n'
        )
        fake = FakeFlatpak()
        rc, _, err = self.run_command(["--file", path], fake)
        self.assertEqual(rc, 1)
        self.assertIn("Unsupported Flatpak entry", err)
        self.assertEqual(fake.installs, [])

    def test_bad_arguments_are_rejected_before_any_flatpak_call(self):
        for args in (["org.example.One; rm -rf /"], [], ["--file"], ["--bogus"]):
            with self.subTest(args=args):
                fake = FakeFlatpak()
                rc, _, _ = self.run_command(args, fake)
                self.assertEqual(rc, 2)
                self.assertEqual(fake.calls, [])
        fake = FakeFlatpak()
        rc, _, err = self.run_command(["--file", os.path.join(self.work.name, "missing")], fake)
        self.assertEqual(rc, 1)
        self.assertIn("Cannot read Brewfile", err)

    def test_flatpak_failure_is_reported(self):
        fake = FakeFlatpak(install_rc=1)
        rc, _, err = self.run_command(["org.example.One"], fake)
        self.assertEqual(rc, 1)
        self.assertIn("exit code 1", err)

    def test_terminal_drops_assumeyes_so_polkit_may_prompt(self):
        fake = FakeFlatpak()
        rc, out, _ = self.run_command(["org.example.One"], fake, tty=True)
        self.assertEqual(rc, 0)
        self.assertEqual(
            fake.installs, [("flatpak", "install", "--system", "flathub", "org.example.One")]
        )
        self.assertNotIn("no seat", out)

    def test_seatless_session_gets_a_password_notice(self):
        fake = FakeFlatpak(remote_session=True)
        with mock.patch.dict(os.environ, {"XDG_SESSION_ID": "7"}):
            rc, out, _ = self.run_command(["org.example.One"], fake, tty=True)
        self.assertEqual(rc, 0)
        self.assertIn("no seat", out)
        self.assertIn(("loginctl", "show-session", "7", "-p", "Remote", "--value"), fake.calls)

    def test_non_terminal_never_consults_the_session(self):
        fake = FakeFlatpak(remote_session=True)
        with mock.patch.dict(os.environ, {"XDG_SESSION_ID": "7"}):
            self.run_command(["org.example.One"], fake)
        self.assertFalse([call for call in fake.calls if call[0] == "loginctl"])


if __name__ == "__main__":
    unittest.main()
