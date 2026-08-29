#!/usr/bin/env python3
"""Unit tests for files/scripts/bst-progress.py.

The script is a byte-transparent filter that build.yml pipes `just bst build`
through, so the contract under test is:

  * every input byte is reproduced on stdout unchanged (TERMINAL/ANSI parsing
    must never swallow or rewrite build output),
  * the TERMINAL regex recognises exactly the BST terminal SUCCESS/SKIPPED
    lines whose message is a `.log` path, after ANSI stripping,
  * elements are deduplicated by artifact hash and upgraded by
    ACTION_PRIORITY (build > pull > fetch > push),
  * `_format_elapsed`, `_emit_progress` and `_write_summary` render the
    counters that the GHA step summary and ::notice:: annotations rely on.

Module-level constants (TOTAL, INTERVAL, SUMMARY_FILE) are read from the
environment at import time, so helper tests reload the module under a patched
environment and end-to-end tests drive it as a subprocess.
"""
import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from io import StringIO
from pathlib import Path
from unittest import mock

REPOSITORY = Path(__file__).resolve().parents[1]
MODULE_PATH = REPOSITORY / "files" / "scripts" / "bst-progress.py"


def load_module(**environ: str):
    """Import bst-progress.py fresh under the given environment overrides."""
    with mock.patch.dict(os.environ, environ, clear=False):
        spec = importlib.util.spec_from_file_location("bst_progress_under_test", MODULE_PATH)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    return module


def terminal_line(artifact_hash: str, action: str, element: str, state: str = "SUCCESS") -> str:
    return (
        f"[23:37:43][00:00:04][{artifact_hash}][{action:>8}:{element}] "
        f"{state} fds/logs/{artifact_hash}-{action}.20260622.log"
    )


class RegexTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load_module()

    def match(self, line: str):
        stripped = self.module.ANSI_ESCAPE.sub("", line)
        return self.module.TERMINAL.search(stripped)

    def test_matches_each_action_type(self) -> None:
        for action in ("pull", "build", "fetch", "push"):
            with self.subTest(action=action):
                m = self.match(terminal_line("d37613a5", action, "fds.bst:steam-devices.bst"))
                self.assertIsNotNone(m)
                self.assertEqual(m.group(1), "d37613a5")
                self.assertEqual(m.group(2), action)
                self.assertEqual(m.group(4), "SUCCESS")

    def test_matches_skipped_state(self) -> None:
        m = self.match(terminal_line("abc123", "pull", "core.bst", state="SKIPPED"))
        self.assertIsNotNone(m)
        self.assertEqual(m.group(4), "SKIPPED")

    def test_strips_ansi_colour_codes_before_matching(self) -> None:
        coloured = (
            "\x1b[1m[23:37:43]\x1b[0m[00:00:04][d37613a5][\x1b[34m    pull\x1b[0m:fds.bst] "
            "\x1b[32mSUCCESS\x1b[0m fds/logs/d37613a5-pull.log"
        )
        self.assertIsNone(self.module.TERMINAL.search(coloured))
        m = self.match(coloured)
        self.assertIsNotNone(m)
        self.assertEqual(m.group(2), "pull")

    def test_ignores_non_terminal_lines(self) -> None:
        for line in (
            "[23:37:43][00:00:04][d37613a5][    pull:fds.bst] START fds/logs/d37613a5-pull.log",
            "[23:37:43][00:00:04][d37613a5][    pull:fds.bst] SUCCESS Pulled artifact",
            "[23:37:43][00:00:04][d37613a5][ unknown:fds.bst] SUCCESS fds/logs/x.log",
            "some unrelated build output",
            "",
        ):
            with self.subTest(line=line):
                self.assertIsNone(self.match(line))

    def test_action_priority_ordering(self) -> None:
        priority = self.module.ACTION_PRIORITY
        self.assertGreater(priority["build"], priority["pull"])
        self.assertGreater(priority["pull"], priority["fetch"])
        self.assertGreater(priority["fetch"], priority["push"])


class FormatElapsedTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load_module()

    def test_sub_hour_uses_mm_ss(self) -> None:
        self.assertEqual(self.module._format_elapsed(0), "00:00")
        self.assertEqual(self.module._format_elapsed(9.9), "00:09")
        self.assertEqual(self.module._format_elapsed(605), "10:05")

    def test_hour_or_more_uses_hh_mm_ss(self) -> None:
        self.assertEqual(self.module._format_elapsed(3600), "01:00:00")
        self.assertEqual(self.module._format_elapsed(3725), "01:02:05")


class EmitProgressTests(unittest.TestCase):
    def capture(self, module, *args, **kwargs) -> str:
        buffer = StringIO()
        with mock.patch("sys.stdout", buffer):
            module._emit_progress(*args, **kwargs)
        return buffer.getvalue()

    def test_with_total_reports_percentage_and_eta(self) -> None:
        module = load_module(ELEMENT_TOTAL="200")
        module.action_counts.update({"pull": 40, "build": 10})
        out = self.capture(module, 50, 100.0)
        self.assertIn(">>> BST Progress: 50/200 (25%)", out)
        self.assertIn("pull:40 build:10", out)
        self.assertIn("::notice::BST 25% — 50/200 elements", out)
        self.assertIn("ETA ~", out)

    def test_final_report_omits_eta(self) -> None:
        module = load_module(ELEMENT_TOTAL="200")
        out = self.capture(module, 200, 100.0, final=True)
        self.assertIn(">>> BST Final: 200/200 (100%)", out)
        self.assertNotIn("ETA", out)
        self.assertIn("done", out)

    def test_without_total_reports_absolute_counts(self) -> None:
        module = load_module(ELEMENT_TOTAL="0")
        module.action_counts.update({"fetch": 3})
        out = self.capture(module, 7, 60.0)
        self.assertIn(">>> BST Progress: 7 elements completed", out)
        self.assertIn("fetch:3", out)
        self.assertIn("elapsed:01:00", out)
        self.assertNotIn("%", out)

    def test_zero_done_does_not_divide_by_zero(self) -> None:
        module = load_module(ELEMENT_TOTAL="200")
        out = self.capture(module, 0, 10.0)
        self.assertIn("0/200 (0%)", out)

    def test_zero_elapsed_does_not_divide_by_zero(self) -> None:
        module = load_module(ELEMENT_TOTAL="200")
        out = self.capture(module, 5, 0.0)
        self.assertIn("0 elem/min", out)


class WriteSummaryTests(unittest.TestCase):
    def test_writes_markdown_table_with_cache_miss_rate(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            summary = Path(tempdir) / "summary.md"
            summary.write_text("preexisting\n")
            module = load_module(ELEMENT_TOTAL="200", GITHUB_STEP_SUMMARY=str(summary))
            module.action_counts.update({"pull": 75, "build": 25, "fetch": 5})
            module._write_summary(100, 600.0)

            text = summary.read_text()
            self.assertTrue(text.startswith("preexisting\n"))
            self.assertIn("## BST Cache Performance", text)
            self.assertIn("| Total elements | 200 |", text)
            self.assertIn("| Completed | 100 (50.0%) |", text)
            self.assertIn("| Cache hits (pull) | 75 |", text)
            self.assertIn("| Local builds (miss) | 25 |", text)
            self.assertIn("| Cache miss rate | 25.0% |", text)
            self.assertIn("| Wall time | 10:00 |", text)
            self.assertIn("| Throughput | 10 elem/min |", text)

    def test_unknown_total_and_zero_done(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            summary = Path(tempdir) / "summary.md"
            module = load_module(ELEMENT_TOTAL="0", GITHUB_STEP_SUMMARY=str(summary))
            module._write_summary(0, 0.0)

            text = summary.read_text()
            self.assertIn("| Total elements | unknown |", text)
            self.assertIn("| Completed | 0 (n/a%) |", text)
            self.assertIn("| Cache miss rate | 0.0% |", text)
            self.assertIn("| Throughput | 0 elem/min |", text)

    def test_no_summary_file_is_a_noop(self) -> None:
        module = load_module(GITHUB_STEP_SUMMARY="")
        with mock.patch("builtins.open", side_effect=AssertionError("must not open")):
            module._write_summary(5, 10.0)

    def test_unwritable_summary_file_is_swallowed(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            unwritable = Path(tempdir) / "missing-dir" / "summary.md"
            module = load_module(GITHUB_STEP_SUMMARY=str(unwritable))
            module._write_summary(5, 10.0)  # must not raise
            self.assertFalse(unwritable.exists())


class MainPipelineTests(unittest.TestCase):
    """End-to-end: drive the script as build.yml does, over a real pipe."""

    def run_filter(self, stdin: bytes, **environ: str) -> subprocess.CompletedProcess:
        env = dict(os.environ)
        env.pop("GITHUB_STEP_SUMMARY", None)
        env.setdefault("BST_PROGRESS_INTERVAL", "999999")
        env.update(environ)
        return subprocess.run(
            [sys.executable, str(MODULE_PATH)],
            input=stdin,
            capture_output=True,
            env=env,
            check=False,
        )

    def test_passes_every_input_byte_through_unchanged(self) -> None:
        payload = (
            b"plain build output\n"
            b"\x1b[32mcoloured\x1b[0m line\n"
            + terminal_line("d37613a5", "pull", "fds.bst").encode()
            + b"\n"
            b"invalid utf-8: \xff\xfe\n"
            b"trailing line without newline"
        )
        result = self.run_filter(payload, ELEMENT_TOTAL="1")
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        self.assertTrue(result.stdout.startswith(payload))

    def test_deduplicates_repeated_artifact_hash(self) -> None:
        lines = "\n".join(
            [
                terminal_line("aaaa1111", "pull", "one.bst"),
                terminal_line("aaaa1111", "pull", "one.bst"),
                terminal_line("bbbb2222", "pull", "two.bst"),
            ]
        ).encode()
        result = self.run_filter(lines, ELEMENT_TOTAL="10")
        out = result.stdout.decode()
        self.assertIn(">>> BST Final: 2/10 (20%)", out)
        self.assertIn("pull:2 build:0", out)

    def test_upgrades_element_to_higher_priority_action(self) -> None:
        lines = "\n".join(
            [
                terminal_line("aaaa1111", "fetch", "one.bst"),
                terminal_line("aaaa1111", "build", "one.bst"),
            ]
        ).encode()
        out = self.run_filter(lines, ELEMENT_TOTAL="1").stdout.decode()
        self.assertIn(">>> BST Final: 1/1 (100%)", out)
        self.assertIn("pull:0 build:1 fetch:0", out)

    def test_ignores_lower_priority_action_after_higher(self) -> None:
        lines = "\n".join(
            [
                terminal_line("aaaa1111", "build", "one.bst"),
                terminal_line("aaaa1111", "fetch", "one.bst"),
            ]
        ).encode()
        out = self.run_filter(lines, ELEMENT_TOTAL="1").stdout.decode()
        self.assertIn(">>> BST Final: 1/1 (100%)", out)
        self.assertIn("pull:0 build:1 fetch:0", out)

    def test_emits_interim_progress_when_interval_elapses(self) -> None:
        lines = "\n".join(
            terminal_line(f"dead{i:04d}", "pull", f"e{i}.bst") for i in range(3)
        ).encode()
        out = self.run_filter(lines, ELEMENT_TOTAL="3", BST_PROGRESS_INTERVAL="0").stdout.decode()
        self.assertGreaterEqual(out.count(">>> BST Progress:"), 3)
        self.assertIn(">>> BST Final: 3/3 (100%)", out)

    def test_empty_input_reports_zero_and_exits_clean(self) -> None:
        result = self.run_filter(b"", ELEMENT_TOTAL="42")
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        self.assertIn(">>> BST Final: 0/42 (0%)", result.stdout.decode())

    def test_writes_step_summary_when_runner_provides_one(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            summary = Path(tempdir) / "summary.md"
            lines = "\n".join(
                [
                    terminal_line("aaaa1111", "pull", "one.bst"),
                    terminal_line("bbbb2222", "build", "two.bst"),
                ]
            ).encode()
            self.run_filter(lines, ELEMENT_TOTAL="2", GITHUB_STEP_SUMMARY=str(summary))
            text = summary.read_text()
            self.assertIn("## BST Cache Performance", text)
            self.assertIn("| Completed | 2 (100.0%) |", text)
            self.assertIn("| Cache hits (pull) | 1 |", text)
            self.assertIn("| Cache miss rate | 50.0% |", text)


if __name__ == "__main__":
    unittest.main()
