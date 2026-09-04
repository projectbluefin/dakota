#!/usr/bin/env python3
"""Unit tests for files/migrate-var-home-passwd/bluefin-migrate-var-home-passwd.

The migration rewrites legacy home fields in /etc/passwd (/var/home/<user>
-> /home/<user>, /var/roothome -> /root) on first boot, delegating the
write to usermod. It ships to /usr/libexec and is enabled by preset, so a
regression here changes passwd on every existing install.

The script exposes MIGRATE_PREFIX for exactly this purpose ("tests only,
leave unset in production"): it selects $MIGRATE_PREFIX/etc/passwd and is
forwarded to usermod as --prefix. These tests drive that hook against a
temporary root with a stub usermod on PATH, so no real account is touched
and no new test dependency is introduced.
"""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[1]
SCRIPT = REPOSITORY / "files" / "migrate-var-home-passwd" / "bluefin-migrate-var-home-passwd"

ROOTHOME = "root:x:0:0::/var/roothome:/bin/bash"

STUB_USERMOD = """#!/usr/bin/bash
printf '%s\\n' "$*" >> "$USERMOD_CALLS"
exit "${USERMOD_RC:-0}"
"""


class MigrateVarHomePasswdTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.prefix = self.tmp / "root"
        (self.prefix / "etc").mkdir(parents=True)
        bindir = self.tmp / "bin"
        bindir.mkdir()
        stub = bindir / "usermod"
        stub.write_text(STUB_USERMOD, encoding="utf-8")
        stub.chmod(0o755)
        self.bindir = bindir
        self.calls = self.tmp / "calls"
        self.addCleanup(self._tmp.cleanup)

    # ── helpers ──────────────────────────────────────────────────────────
    def write_passwd(self, *lines):
        path = self.prefix / "etc" / "passwd"
        path.write_text("".join(line + "\n" for line in lines), encoding="utf-8")
        return path

    def run_migration(self, usermod_rc=0, prefix=None):
        env = dict(os.environ)
        env["PATH"] = f"{self.bindir}:{env['PATH']}"
        env["MIGRATE_PREFIX"] = str(self.prefix if prefix is None else prefix)
        env["USERMOD_CALLS"] = str(self.calls)
        env["USERMOD_RC"] = str(usermod_rc)
        return subprocess.run(
            ["/usr/bin/bash", str(SCRIPT)],
            env=env, capture_output=True, text=True, check=False,
        )

    def usermod_calls(self):
        if not self.calls.exists():
            return []
        return [c for c in self.calls.read_text(encoding="utf-8").splitlines() if c]

    # ── no-op paths ──────────────────────────────────────────────────────
    def test_missing_passwd_is_a_clean_no_op(self):
        result = self.run_migration()
        self.assertEqual(result.returncode, 0)
        self.assertIn("nothing to do", result.stdout)
        self.assertEqual(self.usermod_calls(), [])

    def test_already_migrated_passwd_takes_no_lock_and_stays_silent(self):
        self.write_passwd(
            "root:x:0:0::/root:/bin/bash",
            "alice:x:1000:1000::/home/alice:/bin/bash",
        )
        result = self.run_migration()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(self.usermod_calls(), [])

    def test_var_home_substring_elsewhere_in_line_is_not_matched(self):
        # /var/home appears as a shell path, not as the home field.
        self.write_passwd("alice:x:1000:1000::/home/alice:/var/home/alice/bin/sh")
        result = self.run_migration()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.usermod_calls(), [])

    def test_blank_and_comment_only_passwd_is_a_no_op(self):
        self.write_passwd("", "   ")
        result = self.run_migration()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.usermod_calls(), [])

    # ── migration paths ──────────────────────────────────────────────────
    def test_var_home_user_is_rewritten_under_home(self):
        self.write_passwd(ROOTHOME, "alice:x:1000:1000::/var/home/alice:/bin/bash")
        result = self.run_migration()
        self.assertEqual(result.returncode, 0)
        self.assertIn(
            f"--prefix {self.prefix} -d /home/alice alice", self.usermod_calls()
        )
        self.assertIn("migrated alice: /var/home/alice -> /home/alice", result.stdout)

    def test_var_roothome_maps_to_root_not_home_roothome(self):
        self.write_passwd("root:x:0:0::/var/roothome:/bin/bash")
        result = self.run_migration()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(
            self.usermod_calls(), [f"--prefix {self.prefix} -d /root root"]
        )

    def test_only_the_var_home_prefix_is_replaced(self):
        # A nested home must keep everything after /var/home/ intact.
        self.write_passwd(ROOTHOME, "svc:x:990:990::/var/home/shared/svc:/sbin/nologin")
        self.run_migration()
        self.assertIn(
            f"--prefix {self.prefix} -d /home/shared/svc svc", self.usermod_calls()
        )

    def test_untouched_accounts_are_skipped(self):
        self.write_passwd(
            "bin:x:1:1::/:/sbin/nologin",
            ROOTHOME,
            "alice:x:1000:1000::/var/home/alice:/bin/bash",
            "bob:x:1001:1001::/home/bob:/bin/bash",
            "nobody:x:65534:65534::/:/sbin/nologin",
        )
        result = self.run_migration()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.usermod_calls(), [
            f"--prefix {self.prefix} -d /root root",
            f"--prefix {self.prefix} -d /home/alice alice",
        ])
        self.assertIn("migrated 2 user(s)", result.stdout)

    def test_every_legacy_entry_is_migrated_in_file_order(self):
        self.write_passwd(
            "alice:x:1000:1000::/var/home/alice:/bin/bash",
            "root:x:0:0::/var/roothome:/bin/bash",
            "carol:x:1002:1002::/var/home/carol:/bin/bash",
        )
        result = self.run_migration()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.usermod_calls(), [
            f"--prefix {self.prefix} -d /home/alice alice",
            f"--prefix {self.prefix} -d /root root",
            f"--prefix {self.prefix} -d /home/carol carol",
        ])
        self.assertIn("migrated 3 user(s)", result.stdout)

    def test_prefix_is_forwarded_to_usermod(self):
        self.write_passwd(ROOTHOME, "alice:x:1000:1000::/var/home/alice:/bin/bash")
        self.run_migration()
        self.assertTrue(self.usermod_calls()[0].startswith(f"--prefix {self.prefix} "))

    def test_passwd_file_itself_is_not_rewritten_by_the_script(self):
        # The write is delegated to usermod so locking stays canonical.
        path = self.write_passwd(ROOTHOME, "alice:x:1000:1000::/var/home/alice:/bin/bash")
        before = path.read_text(encoding="utf-8")
        self.run_migration()
        self.assertEqual(path.read_text(encoding="utf-8"), before)

    # ── fast-path gate (characterisation — see dakota issue linked in the PR) ──
    def test_var_home_only_passwd_is_skipped_by_the_grep_fast_path(self):
        # Current behaviour, NOT desired behaviour: the gate regex is
        # ':(/var/home/|/var/roothome)(:|$)', which requires ':' or end-of-line
        # immediately after '/var/home/'. A real field is '/var/home/alice', so
        # only the '/var/roothome' alternative can ever match. With root already
        # migrated, user entries are never reached. Locked in so the fix flips
        # this assertion deliberately rather than by accident.
        self.write_passwd(
            "root:x:0:0::/root:/bin/bash",
            "alice:x:1000:1000::/var/home/alice:/bin/bash",
        )
        result = self.run_migration()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.usermod_calls(), [])

    def test_roothome_entry_admits_var_home_users_to_the_loop(self):
        # The mirror of the test above: the same alice entry IS migrated once
        # an unmigrated root entry lets execution past the gate.
        self.write_passwd(
            ROOTHOME,
            "alice:x:1000:1000::/var/home/alice:/bin/bash",
        )
        self.run_migration()
        self.assertIn(
            f"--prefix {self.prefix} -d /home/alice alice", self.usermod_calls()
        )

    # ── failure handling ─────────────────────────────────────────────────
    def test_usermod_failure_reports_nonzero_without_aborting_the_run(self):
        self.write_passwd(
            ROOTHOME,
            "alice:x:1000:1000::/var/home/alice:/bin/bash",
            "carol:x:1002:1002::/var/home/carol:/bin/bash",
        )
        result = self.run_migration(usermod_rc=8)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(self.usermod_calls()), 3)
        self.assertIn("FAILED to migrate alice", result.stdout)
        self.assertIn("FAILED to migrate carol", result.stdout)
        self.assertIn("usermod rc=8", result.stdout)

    def test_failed_migrations_are_not_counted_as_migrated(self):
        self.write_passwd(ROOTHOME, "alice:x:1000:1000::/var/home/alice:/bin/bash")
        result = self.run_migration(usermod_rc=8)
        self.assertIn("migrated 0 user(s)", result.stdout)

    def test_log_lines_are_prefixed_with_the_unit_name(self):
        self.write_passwd(ROOTHOME, "alice:x:1000:1000::/var/home/alice:/bin/bash")
        result = self.run_migration()
        for line in result.stdout.splitlines():
            self.assertTrue(line.startswith("bluefin-migrate-var-home-passwd: "), line)


if __name__ == "__main__":
    unittest.main()
