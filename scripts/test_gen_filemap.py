#!/usr/bin/env python3
"""Unit tests for scripts/gen-filemap.py.

Covers strip_ansi, guess_interval, bst, list_elements, list_all_contents and
main() (filemap assembly, oci/layers skipping, TSV manifest, --dry-run).
"""
import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock


REPOSITORY = Path(__file__).resolve().parents[1]
MODULE_PATH = REPOSITORY / "scripts" / "gen-filemap.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("gen_filemap", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


gen_filemap = _load_module()


class StripAnsiTests(unittest.TestCase):
    def test_removes_color_codes(self) -> None:
        self.assertEqual(gen_filemap.strip_ansi("\x1b[32mbluefin.bst\x1b[0m"), "bluefin.bst")

    def test_removes_multi_parameter_codes(self) -> None:
        self.assertEqual(gen_filemap.strip_ansi("\x1b[1;31merror\x1b[0m"), "error")

    def test_leaves_plain_text_untouched(self) -> None:
        self.assertEqual(gen_filemap.strip_ansi("gnome/mutter.bst"), "gnome/mutter.bst")


class GuessIntervalTests(unittest.TestCase):
    def test_bluefin_elements_are_weekly(self) -> None:
        self.assertEqual(gen_filemap.guess_interval("bluefin/ghostty.bst"), "weekly")

    def test_fast_moving_gnome_elements_are_weekly(self) -> None:
        for element in ("gnome/gnome-shell.bst", "gnome/mutter.bst",
                        "gnome/gdm.bst", "gnome/nautilus.bst"):
            with self.subTest(element=element):
                self.assertEqual(gen_filemap.guess_interval(element), "weekly")

    def test_other_gnome_elements_are_monthly(self) -> None:
        self.assertEqual(gen_filemap.guess_interval("gnome/gnome-calculator.bst"), "monthly")

    def test_freedesktop_sdk_is_monthly(self) -> None:
        self.assertEqual(gen_filemap.guess_interval("freedesktop-sdk.bst"), "monthly")

    def test_first_hint_wins_over_later_hint(self) -> None:
        # Matches both "bluefin/" and "gnome/" — the earlier hint must win.
        self.assertEqual(gen_filemap.guess_interval("bluefin/gnome/patch.bst"), "weekly")

    def test_unknown_element_falls_back_to_default(self) -> None:
        self.assertEqual(gen_filemap.guess_interval("misc/thing.bst"),
                         gen_filemap.DEFAULT_INTERVAL)


class BstTests(unittest.TestCase):
    def test_returns_stdout_on_success(self) -> None:
        completed = subprocess.CompletedProcess(args=[], returncode=0, stdout="ok\n", stderr="")
        with mock.patch.object(gen_filemap.subprocess, "run", return_value=completed) as run:
            self.assertEqual(gen_filemap.bst("show", "--deps", "all"), "ok\n")
        run.assert_called_once()
        self.assertEqual(run.call_args.args[0], ["just", "bst", "show", "--deps", "all"])
        self.assertEqual(run.call_args.kwargs["cwd"], gen_filemap.PROJECT_ROOT)

    def test_exits_nonzero_on_failure(self) -> None:
        completed = subprocess.CompletedProcess(args=[], returncode=2, stdout="", stderr="boom")
        with mock.patch.object(gen_filemap.subprocess, "run", return_value=completed), \
             mock.patch.object(sys, "stderr", new=io.StringIO()):
            with self.assertRaises(SystemExit) as ctx:
                gen_filemap.bst("show")
        self.assertNotEqual(ctx.exception.code, 0)


class ListElementsTests(unittest.TestCase):
    def test_keeps_only_bst_element_names(self) -> None:
        out = (
            "bluefin/ghostty.bst\n"
            "gnome/mutter.bst\n"
            "secure-boot-key-value\n"
            "\n"
        )
        with mock.patch.object(gen_filemap, "bst", return_value=out):
            self.assertEqual(gen_filemap.list_elements("oci/layers/bluefin.bst"),
                             ["bluefin/ghostty.bst", "gnome/mutter.bst"])

    def test_strips_ansi_and_whitespace(self) -> None:
        out = "  \x1b[32mbluefin/ghostty.bst\x1b[0m  \n"
        with mock.patch.object(gen_filemap, "bst", return_value=out):
            self.assertEqual(gen_filemap.list_elements("t.bst"), ["bluefin/ghostty.bst"])

    def test_passes_target_through_to_bst(self) -> None:
        with mock.patch.object(gen_filemap, "bst", return_value="") as bst:
            gen_filemap.list_elements("oci/layers/bluefin.bst")
        bst.assert_called_once_with("show", "--format", "%{name}", "--deps", "all",
                                    "oci/layers/bluefin.bst")


class ListAllContentsTests(unittest.TestCase):
    SAMPLE = (
        "bluefin/ghostty.bst:\n"
        "\t-rwxr-xr-x  exe  32003936  usr/bin/ghostty\n"
        "\tdrwxr-xr-x  dir  4096      usr/share/ghostty\n"
        "\t-rw-r--r--  reg  1024      usr/share/ghostty/themes.conf\n"
        "\n"
        "gnome/mutter.bst:\n"
        "\t-rw-r--r--  reg  2048      usr/lib/libmutter.so\n"
    )

    def _contents(self, out: str):
        with mock.patch.object(gen_filemap, "bst", return_value=out):
            with mock.patch.object(sys, "stderr", new=io.StringIO()):
                return gen_filemap.list_all_contents(["bluefin/ghostty.bst", "gnome/mutter.bst"])

    def test_groups_paths_under_their_element(self) -> None:
        result = self._contents(self.SAMPLE)
        self.assertEqual(result, {
            "bluefin/ghostty.bst": ["/usr/bin/ghostty", "/usr/share/ghostty/themes.conf"],
            "gnome/mutter.bst": ["/usr/lib/libmutter.so"],
        })

    def test_directories_are_skipped(self) -> None:
        result = self._contents(self.SAMPLE)
        self.assertNotIn("/usr/share/ghostty", result["bluefin/ghostty.bst"])

    def test_ignores_entries_before_any_header(self) -> None:
        result = self._contents("\t-rw-r--r--  reg  10  usr/bin/orphan\n")
        self.assertEqual(result, {})

    def test_ignores_short_malformed_rows(self) -> None:
        result = self._contents("a.bst:\n\t-rw-r--r--  reg\n")
        self.assertEqual(result, {})

    def test_strips_ansi_from_headers_and_rows(self) -> None:
        out = (
            "\x1b[34ma.bst:\x1b[0m\n"
            "\t-rw-r--r--  reg  10  \x1b[32musr/bin/a\x1b[0m\n"
        )
        self.assertEqual(self._contents(out), {"a.bst": ["/usr/bin/a"]})

    def test_passes_all_elements_in_one_call(self) -> None:
        with mock.patch.object(gen_filemap, "bst", return_value="") as bst:
            with mock.patch.object(sys, "stderr", new=io.StringIO()):
                gen_filemap.list_all_contents(["a.bst", "b.bst"])
        bst.assert_called_once_with("artifact", "list-contents", "--long", "a.bst", "b.bst")


class MainTests(unittest.TestCase):
    CONTENTS = {
        "bluefin/ghostty.bst": ["/usr/bin/ghostty"],
        "gnome/gnome-calculator.bst": ["/usr/bin/gnome-calculator"],
        "oci/layers/bluefin.bst": ["/usr/bin/ghostty", "/usr/bin/gnome-calculator"],
        "empty/thing.bst": [],
    }

    def _run_main(self, argv, contents=None, output_path=None):
        contents = self.CONTENTS if contents is None else contents
        patches = [
            mock.patch.object(sys, "argv", ["gen-filemap.py", *argv]),
            mock.patch.object(sys, "stderr", new=io.StringIO()),
            mock.patch.object(gen_filemap, "list_elements", return_value=list(contents)),
            mock.patch.object(gen_filemap, "list_uncached_elements", return_value=[]),
            mock.patch.object(gen_filemap, "list_all_contents", return_value=contents),
        ]
        if output_path is not None:
            patches.append(mock.patch.object(gen_filemap, "OUTPUT_PATH", output_path))
        stdout = io.StringIO()
        for patcher in patches:
            patcher.start()
        try:
            with redirect_stdout(stdout):
                rc = gen_filemap.main()
        finally:
            for patcher in reversed(patches):
                patcher.stop()
        return rc, stdout.getvalue()

    def test_dry_run_emits_filemap_json(self) -> None:
        rc, out = self._run_main(["--dry-run"])
        self.assertEqual(rc, 0)
        filemap = json.loads(out)
        self.assertEqual(filemap["bluefin/ghostty.bst"],
                         {"interval": "weekly", "files": ["/usr/bin/ghostty"]})
        self.assertEqual(filemap["gnome/gnome-calculator.bst"]["interval"], "monthly")

    def test_dry_run_skips_oci_layer_and_empty_elements(self) -> None:
        _, out = self._run_main(["--dry-run"])
        filemap = json.loads(out)
        self.assertNotIn("oci/layers/bluefin.bst", filemap)
        self.assertNotIn("empty/thing.bst", filemap)

    def test_dry_run_writes_no_files(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            output = Path(tempdir) / "files" / "filemap.json"
            self._run_main(["--dry-run"], output_path=output)
            self.assertFalse(output.exists())
            self.assertFalse((output.parent / "fakecap-manifest.tsv").exists())

    def test_writes_filemap_and_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            output = Path(tempdir) / "files" / "filemap.json"
            rc, _ = self._run_main([], output_path=output)
            self.assertEqual(rc, 0)
            filemap = json.loads(output.read_text(encoding="utf-8"))
            self.assertIn("bluefin/ghostty.bst", filemap)

            manifest = (output.parent / "fakecap-manifest.tsv").read_text(encoding="utf-8")
            lines = manifest.splitlines()
            self.assertTrue(lines[0].startswith("#"))
            self.assertIn("/usr/bin/ghostty\tbluefin/ghostty.bst\tweekly", lines)
            self.assertIn("/usr/bin/gnome-calculator\tgnome/gnome-calculator.bst\tmonthly", lines)
            self.assertEqual(len(lines), 3)

    def test_file_lists_are_sorted(self) -> None:
        contents = {"bluefin/a.bst": ["/usr/bin/z", "/usr/bin/a"]}
        _, out = self._run_main(["--dry-run"], contents=contents)
        self.assertEqual(json.loads(out)["bluefin/a.bst"]["files"],
                         ["/usr/bin/a", "/usr/bin/z"])

    def test_target_argument_is_forwarded(self) -> None:
        with mock.patch.object(sys, "argv", ["gen-filemap.py", "--dry-run",
                                             "--target", "oci/custom.bst"]), \
             mock.patch.object(sys, "stderr", new=io.StringIO()), \
             mock.patch.object(gen_filemap, "list_elements", return_value=[]) as list_elements, \
             mock.patch.object(gen_filemap, "list_uncached_elements", return_value=[]), \
             mock.patch.object(gen_filemap, "list_all_contents", return_value={}), \
             redirect_stdout(io.StringIO()):
            gen_filemap.main()
        list_elements.assert_called_once_with("oci/custom.bst")

    def test_default_target_used_when_unspecified(self) -> None:
        with mock.patch.object(sys, "argv", ["gen-filemap.py", "--dry-run"]), \
             mock.patch.object(sys, "stderr", new=io.StringIO()), \
             mock.patch.object(gen_filemap, "list_elements", return_value=[]) as list_elements, \
             mock.patch.object(gen_filemap, "list_uncached_elements", return_value=[]), \
             mock.patch.object(gen_filemap, "list_all_contents", return_value={}), \
             redirect_stdout(io.StringIO()):
            gen_filemap.main()
        list_elements.assert_called_once_with(gen_filemap.DEFAULT_TARGET)


class UncachedGateTests(unittest.TestCase):
    """main() must refuse to generate against a partial artifact cache."""

    def test_uncached_elements_abort_generation(self) -> None:
        contents = {"bluefin/ghostty.bst": ["/usr/bin/ghostty"]}
        stderr = io.StringIO()
        with mock.patch.object(sys, "argv", ["gen-filemap.py", "--dry-run"]), \
             mock.patch.object(sys, "stderr", stderr), \
             mock.patch.object(gen_filemap, "list_elements", return_value=list(contents)), \
             mock.patch.object(gen_filemap, "list_uncached_elements",
                               return_value=["bluefin/zig.bst"]), \
             mock.patch.object(gen_filemap, "list_all_contents") as contents_mock:
            rc = gen_filemap.main()
        self.assertEqual(rc, 1)
        self.assertIn("uncached: bluefin/zig.bst", stderr.getvalue())
        contents_mock.assert_not_called()

    def test_state_parsing_flags_non_cached(self) -> None:
        show_output = "\n".join([
            "core/linux-fdsdk.bst:cached",
            "bluefin/zig.bst:buildable",
            "bluefin/ghostty.bst:cached",
            "freedesktop-sdk.bst:components/example.bst:fetch needed",
        ])
        with mock.patch.object(gen_filemap, "bst", return_value=show_output):
            self.assertEqual(gen_filemap.list_uncached_elements("x"),
                             ["bluefin/zig.bst",
                              "freedesktop-sdk.bst:components/example.bst"])

    @unittest.skipUnless(shutil.which("just"), "just is required")
    def test_state_format_survives_just_wrapper(self) -> None:
        # Exercise the real Justfile without launching a container.
        with tempfile.TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            podman = root / "podman"
            podman.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            podman.chmod(0o755)
            env = {
                "PATH": tempdir + os.pathsep + os.environ.get("PATH", ""),
                "HOME": tempdir,
            }
            with mock.patch.dict(os.environ, env):
                # Wrap rather than mock away bst(): capture the arguments
                # received by the fake podman after shell interpolation.
                with mock.patch.object(
                    gen_filemap, "bst", wraps=gen_filemap.bst
                ) as bst:
                    gen_filemap.list_uncached_elements("target.bst")
                    args = gen_filemap.bst(*bst.call_args.args).splitlines()
            index = args.index("--format")
            self.assertEqual(args[index + 1], "%{name}:%{state}")
            self.assertEqual(args[index + 2], "--deps")


class KernelFilemapConsistencyTests(unittest.TestCase):
    """The committed filemap must map the kernels the elements actually pin.

    This is the tripwire for regenerating the filemap against artifacts from
    an older kernel: the 2026-09 regeneration shipped 7.1.8 module paths into
    images running 7.2.2.
    """

    @staticmethod
    def _pinned_version(element_path: Path, suffix: str = "") -> str:
        import re
        ref = re.search(r"^  ref: v([0-9][^-\s]*)-",
                        element_path.read_text(), re.M)
        assert ref, f"no pinned ref in {element_path}"
        return ref.group(1) + suffix

    def test_filemap_matches_pinned_kernel_version(self) -> None:
        # The filemap is generated from DEFAULT_TARGET (the default variant),
        # so it only ever contains the linux-fdsdk kernel; the ogc kernel
        # lives in the gaming variant's tree and has never been mapped.
        filemap_path = REPOSITORY / "files" / "filemap.json"
        fdsdk = REPOSITORY / "elements" / "core" / "linux-fdsdk.bst"
        if not (filemap_path.exists() and fdsdk.exists()):
            self.skipTest("repo files not present")
        version = self._pinned_version(fdsdk)
        text = filemap_path.read_text()
        # assertIn would embed the 70MB filemap in the failure message.
        self.assertTrue(f"/usr/lib/modules/{version}" in text,
                        f"filemap has no module paths for pinned kernel {version}; "
                        "regenerate it against current artifacts")


if __name__ == "__main__":
    unittest.main()
