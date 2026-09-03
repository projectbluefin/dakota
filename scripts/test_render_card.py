#!/usr/bin/env python3
"""Unit tests for .github/scripts/render_card.py.

Covers the pure renderers (render_chip, render_diff_bar, build_html),
the release-notes markdown builder (build_release_notes) and the main()
CLI contract with the Playwright screenshot boundary stubbed out.
"""
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

REPOSITORY = Path(__file__).resolve().parents[1]
MODULE_PATH = REPOSITORY / ".github" / "scripts" / "render_card.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("render_card_under_test", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


render_card = _load_module()


def _versions(has_prev=True, notable=None, diff=None):
    return {
        "has_prev": has_prev,
        "notable": notable if notable is not None else [
            {"name": "kernel", "version": "6.14.2", "prev": "6.14.1", "changed": True},
            {"name": "mesa", "version": "25.0.3", "changed": False},
        ],
        "diff": diff if diff is not None else {
            "changed_count": 1,
            "added_count": 1,
            "removed_count": 1,
            "changed": [{"name": "kernel", "prev": "6.14.1", "curr": "6.14.2"}],
            "added": [{"name": "nethogs", "version": "0.8.7"}],
            "removed": [{"name": "cowsay", "version": "3.8.4"}],
        },
    }


class RenderChipTests(unittest.TestCase):
    def test_unchanged_chip_has_no_prev_or_arrow(self):
        chip = render_card.render_chip({"name": "mesa", "version": "25.0.3"})
        self.assertIn('<span class="chip-label">mesa</span>', chip)
        self.assertIn('<span class="chip-value">25.0.3</span>', chip)
        self.assertNotIn("chip-prev", chip)
        self.assertNotIn("chip-arrow", chip)
        self.assertIn('class="chip"', chip)

    def test_changed_chip_renders_prev_and_arrow(self):
        chip = render_card.render_chip(
            {"name": "kernel", "version": "6.14.2", "prev": "6.14.1", "changed": True}
        )
        self.assertIn('class="chip changed"', chip)
        self.assertIn('<span class="chip-prev">6.14.1</span>', chip)
        self.assertIn("chip-arrow", chip)

    def test_changed_without_prev_omits_prev_markup(self):
        chip = render_card.render_chip(
            {"name": "kernel", "version": "6.14.2", "changed": True}
        )
        self.assertIn('class="chip changed"', chip)
        self.assertNotIn("chip-prev", chip)
        self.assertNotIn("chip-arrow", chip)

    def test_name_and_version_are_html_escaped(self):
        chip = render_card.render_chip(
            {
                "name": "<script>",
                "version": "1&2",
                "prev": '"quoted"',
                "changed": True,
            }
        )
        self.assertNotIn("<script>", chip)
        self.assertIn("&lt;script&gt;", chip)
        self.assertIn("1&amp;2", chip)
        self.assertIn("&quot;quoted&quot;", chip)

    def test_missing_version_key_raises(self):
        with self.assertRaises(KeyError):
            render_card.render_chip({"name": "mesa"})


class RenderDiffBarTests(unittest.TestCase):
    def test_no_previous_baseline_renders_nothing(self):
        self.assertEqual(render_card.render_diff_bar(_versions()["diff"], False), "")

    def test_all_three_counts_render_in_fixed_order(self):
        bar = render_card.render_diff_bar(_versions()["diff"], True)
        self.assertLess(bar.index("1 updated"), bar.index("1 added"))
        self.assertLess(bar.index("1 added"), bar.index("1 removed"))
        self.assertIn('class="diff-bar"', bar)

    def test_zero_counts_are_omitted(self):
        diff = {"changed_count": 0, "added_count": 2, "removed_count": 0}
        bar = render_card.render_diff_bar(diff, True)
        self.assertIn("2 added", bar)
        self.assertNotIn("updated", bar)
        self.assertNotIn("removed", bar)

    def test_all_zero_counts_fall_back_to_no_changes_text(self):
        diff = {"changed_count": 0, "added_count": 0, "removed_count": 0}
        bar = render_card.render_diff_bar(diff, True)
        self.assertIn("No package changes since last release", bar)


class BuildHtmlTests(unittest.TestCase):
    def test_renders_tag_sha_and_long_date(self):
        out = render_card.build_html(_versions(), "2294ec1", "2026-05-14-2294ec1", "2026-05-14")
        self.assertIn("2026-05-14-2294ec1", out)
        self.assertIn("2294ec1", out)
        self.assertIn("May 14, 2026", out)

    def test_embeds_chips_and_diff_bar(self):
        out = render_card.build_html(_versions(), "2294ec1", "tag", "2026-05-14")
        self.assertIn('<span class="chip-label">kernel</span>', out)
        self.assertIn('<span class="chip-label">mesa</span>', out)
        self.assertIn('class="diff-bar"', out)

    def test_first_release_has_no_diff_bar(self):
        out = render_card.build_html(
            _versions(has_prev=False), "2294ec1", "tag", "2026-05-14"
        )
        self.assertNotIn('class="diff-bar"', out)

    def test_output_loads_no_external_resources(self):
        # Playwright renders this offline; any fetched resource would hang or
        # silently drop styling in the screenshot.
        out = render_card.build_html(_versions(), "2294ec1", "tag", "2026-05-14")
        self.assertTrue(out.lstrip().startswith("<!DOCTYPE html>"))
        for marker in ("<link", "<script", "src=", "@import", "url("):
            self.assertNotIn(marker, out)

    def test_invalid_date_raises(self):
        with self.assertRaises(ValueError):
            render_card.build_html(_versions(), "2294ec1", "tag", "14-05-2026")


class BuildReleaseNotesTests(unittest.TestCase):
    def _notes(self, versions=None, repo="projectbluefin/dakota"):
        return render_card.build_release_notes(
            versions=versions if versions is not None else _versions(),
            sha="2294ec1abc1234567890abcd",
            sha7="2294ec1",
            tag="2026-05-14-2294ec1",
            date="2026-05-14",
            repo=repo,
        )

    def test_starts_with_release_card_image_and_ends_with_newline(self):
        notes = self._notes()
        self.assertTrue(notes.startswith("![Bluefin Dakota 2026-05-14-2294ec1]"))
        self.assertIn(
            "https://github.com/projectbluefin/dakota/releases/download/"
            "2026-05-14-2294ec1/release-card.png",
            notes,
        )
        self.assertTrue(notes.endswith("\n"))

    def test_diff_line_lists_all_three_categories(self):
        self.assertIn("**1 updated, 1 added, 1 removed** packages since last release.", self._notes())

    def test_diff_line_without_changes(self):
        versions = _versions(
            diff={
                "changed_count": 0,
                "added_count": 0,
                "removed_count": 0,
                "changed": [],
                "added": [],
                "removed": [],
            }
        )
        notes = self._notes(versions)
        self.assertIn("No package changes since last release.", notes)
        self.assertNotIn("<details>", notes)

    def test_first_release_omits_full_diff_section(self):
        notes = self._notes(_versions(has_prev=False))
        self.assertIn("First automated release — no previous baseline.", notes)
        self.assertNotIn("## All package changes", notes)
        self.assertNotIn("<details>", notes)

    def test_notable_table_marks_changed_and_unchanged_rows(self):
        notes = self._notes()
        self.assertIn("| kernel | `6.14.2` | `6.14.1` → `6.14.2` |", notes)
        self.assertIn("| mesa | `25.0.3` | — |", notes)

    def test_full_diff_sections_render_each_category(self):
        notes = self._notes()
        self.assertIn("<details><summary>↑ 1 updated packages</summary>", notes)
        self.assertIn("| kernel | `6.14.1` | `6.14.2` |", notes)
        self.assertIn("<details><summary>+ 1 added packages</summary>", notes)
        self.assertIn("| nethogs | `0.8.7` |", notes)
        self.assertIn("<details><summary>− 1 removed packages</summary>", notes)
        self.assertIn("| cowsay | `3.8.4` |", notes)

    def test_sections_absent_when_their_list_is_empty(self):
        versions = _versions(
            diff={
                "changed_count": 0,
                "added_count": 1,
                "removed_count": 0,
                "changed": [],
                "added": [{"name": "nethogs", "version": "0.8.7"}],
                "removed": [],
            }
        )
        notes = self._notes(versions)
        self.assertIn("+ 1 added packages", notes)
        self.assertNotIn("updated packages</summary>", notes)
        self.assertNotIn("removed packages</summary>", notes)

    def test_image_refs_use_full_sha_not_short_sha(self):
        notes = self._notes()
        self.assertIn("ghcr.io/projectbluefin/dakota:2294ec1abc1234567890abcd", notes)
        self.assertIn("ghcr.io/projectbluefin/dakota:latest", notes)

    def test_cosign_identity_regexp_pins_publish_workflow_on_main(self):
        notes = self._notes()
        self.assertIn(
            r"^https://github\.com/projectbluefin/dakota/\.github/workflows/publish\.yml"
            r"@refs/heads/(main|gh-readonly-queue/main/.+)$",
            notes,
        )
        self.assertIn(
            "--certificate-oidc-issuer https://token.actions.githubusercontent.com",
            notes,
        )

    def test_verification_commands_are_present(self):
        notes = self._notes()
        self.assertIn("oras discover ghcr.io/projectbluefin/dakota:2294ec1abc1234567890abcd", notes)
        self.assertIn(
            "gh attestation verify oci://ghcr.io/projectbluefin/dakota:"
            "2294ec1abc1234567890abcd \\",
            notes,
        )
        self.assertIn("--repo projectbluefin/dakota", notes)

    def test_no_line_starts_with_four_spaces(self):
        # A 4-space indent renders as a code block in GitHub markdown.
        for line in self._notes().splitlines():
            self.assertFalse(line.startswith("    "), msg=line)


class MainTests(unittest.TestCase):
    def _run_main(self, tmpdir, extra_args=(), versions=None):
        versions_path = Path(tmpdir) / "versions.json"
        versions_path.write_text(
            json.dumps(versions if versions is not None else _versions()),
            encoding="utf-8",
        )
        notes_path = Path(tmpdir) / "release-notes.md"
        out_png = Path(tmpdir) / "release-card.png"
        argv = [
            "render_card.py",
            "--versions", str(versions_path),
            "--sha", "2294ec1abc1234567890abcd",
            "--sha7", "2294ec1",
            "--date", "2026-05-14",
            "--tag", "2026-05-14-2294ec1",
            "--repo", "projectbluefin/dakota",
            "--output", str(out_png),
            "--release-notes", str(notes_path),
            *extra_args,
        ]
        captured = []

        def fake_screenshot(html_path, output_path):
            captured.append((Path(html_path).read_text(encoding="utf-8"), output_path))

        with mock.patch.object(sys, "argv", argv), \
                mock.patch.object(render_card, "screenshot", fake_screenshot), \
                redirect_stdout(io.StringIO()) as out:
            render_card.main()
        return captured, notes_path, out_png, out.getvalue()

    def test_writes_release_notes_and_screenshots_the_card(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            captured, notes_path, out_png, stdout = self._run_main(tmpdir)
            self.assertEqual(len(captured), 1)
            card_html, screenshot_target = captured[0]
            self.assertIn("2026-05-14-2294ec1", card_html)
            self.assertEqual(screenshot_target, str(out_png))
            self.assertIn(
                "## Key component versions", notes_path.read_text(encoding="utf-8")
            )
            self.assertIn(str(notes_path), stdout)

    def test_temporary_html_file_is_removed_after_render(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            captured, _, _, _ = self._run_main(tmpdir)
            leaked = list(Path(tmpdir).glob("*.html")) + list(Path.cwd().glob("tmp*.html"))
        self.assertEqual(leaked, [])

    def test_temporary_html_file_is_removed_when_screenshot_fails(self):
        before = set(Path.cwd().glob("*.html"))
        with tempfile.TemporaryDirectory() as tmpdir:
            versions_path = Path(tmpdir) / "versions.json"
            versions_path.write_text(json.dumps(_versions()), encoding="utf-8")
            argv = [
                "render_card.py",
                "--versions", str(versions_path),
                "--sha", "2294ec1abc1234567890abcd",
                "--sha7", "2294ec1",
                "--date", "2026-05-14",
                "--tag", "tag",
                "--repo", "projectbluefin/dakota",
                "--output", str(Path(tmpdir) / "card.png"),
                "--release-notes", str(Path(tmpdir) / "notes.md"),
            ]
            def boom(html_path, output_path):
                raise RuntimeError("playwright unavailable")

            with mock.patch.object(sys, "argv", argv), \
                    mock.patch.object(render_card, "screenshot", boom), \
                    redirect_stdout(io.StringIO()):
                with self.assertRaises(RuntimeError):
                    render_card.main()
        self.assertEqual(set(Path.cwd().glob("*.html")) - before, set())

    def test_release_notes_are_not_written_when_screenshot_fails(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            versions_path = Path(tmpdir) / "versions.json"
            versions_path.write_text(json.dumps(_versions()), encoding="utf-8")
            notes_path = Path(tmpdir) / "notes.md"
            argv = [
                "render_card.py",
                "--versions", str(versions_path),
                "--sha", "sha", "--sha7", "sha7",
                "--date", "2026-05-14", "--tag", "tag",
                "--repo", "projectbluefin/dakota",
                "--output", str(Path(tmpdir) / "card.png"),
                "--release-notes", str(notes_path),
            ]

            def boom(html_path, output_path):
                raise RuntimeError("playwright unavailable")

            with mock.patch.object(sys, "argv", argv), \
                    mock.patch.object(render_card, "screenshot", boom), \
                    redirect_stdout(io.StringIO()):
                with self.assertRaises(RuntimeError):
                    render_card.main()
            self.assertFalse(notes_path.exists())

    def test_output_and_release_notes_have_defaults(self):
        parser_defaults = {}
        real_parse = render_card.argparse.ArgumentParser.parse_args

        def capture(self_, *a, **kw):
            ns = real_parse(self_, *a, **kw)
            parser_defaults.update(vars(ns))
            return ns

        with tempfile.TemporaryDirectory() as tmpdir:
            versions_path = Path(tmpdir) / "versions.json"
            versions_path.write_text(json.dumps(_versions()), encoding="utf-8")
            argv = [
                "render_card.py",
                "--versions", str(versions_path),
                "--sha", "sha", "--sha7", "sha7",
                "--date", "2026-05-14", "--tag", "tag",
                "--repo", "projectbluefin/dakota",
            ]
            cwd = Path.cwd()
            try:
                import os
                os.chdir(tmpdir)
                with mock.patch.object(sys, "argv", argv), \
                        mock.patch.object(render_card, "screenshot", lambda h, o: None), \
                        mock.patch.object(
                            render_card.argparse.ArgumentParser, "parse_args", capture
                        ), \
                        redirect_stdout(io.StringIO()):
                    render_card.main()
            finally:
                os.chdir(cwd)
        self.assertEqual(parser_defaults["output"], "release-card.png")
        self.assertEqual(parser_defaults["release_notes"], "release-notes.md")

    def test_missing_required_argument_exits_non_zero(self):
        with mock.patch.object(sys, "argv", ["render_card.py", "--versions", "v.json"]), \
                mock.patch("sys.stderr", new_callable=io.StringIO):
            with self.assertRaises(SystemExit) as ctx:
                render_card.main()
        self.assertNotEqual(ctx.exception.code, 0)


if __name__ == "__main__":
    unittest.main()
