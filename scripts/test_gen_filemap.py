#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch


REPOSITORY = Path(__file__).resolve().parents[1]
SCRIPT = REPOSITORY / "scripts" / "gen-filemap.py"
SPEC = importlib.util.spec_from_file_location("gen_filemap", SCRIPT)
assert SPEC and SPEC.loader
GEN_FILEMAP = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN_FILEMAP)


class GenFilemapTests(unittest.TestCase):
    def test_strip_ansi_removes_escape_codes(self) -> None:
        value = "\x1b[32mbluefin/a.bst\x1b[0m"
        self.assertEqual(GEN_FILEMAP.strip_ansi(value), "bluefin/a.bst")

    def test_guess_interval_uses_first_matching_hint(self) -> None:
        self.assertEqual(GEN_FILEMAP.guess_interval("gnome/mutter.bst"), "weekly")
        self.assertEqual(GEN_FILEMAP.guess_interval("random/component.bst"), "monthly")

    @patch.object(GEN_FILEMAP, "bst")
    def test_list_elements_filters_non_bst_lines(self, mock_bst) -> None:
        mock_bst.return_value = (
            "bluefin/a.bst\n"
            "\x1b[33mgnome/mutter.bst\x1b[0m\n"
            "secure-boot-signing-key\n"
            "not-an-element\n"
        )
        self.assertEqual(
            GEN_FILEMAP.list_elements("oci/layers/bluefin.bst"),
            ["bluefin/a.bst", "gnome/mutter.bst"],
        )

    @patch.object(GEN_FILEMAP, "bst")
    def test_list_all_contents_parses_element_file_entries(self, mock_bst) -> None:
        mock_bst.return_value = (
            "bluefin/a.bst:\n"
            "\t-rwxr-xr-x exe 32003936 usr/bin/ghostty\n"
            "\tdrwxr-xr-x dir 0 usr/lib\n"
            "bluefin/b.bst:\n"
            "\t-rw-r--r-- reg 100 etc/bluefin/config\n"
            "\tinvalid-entry\n"
        )
        parsed = GEN_FILEMAP.list_all_contents(["bluefin/a.bst", "bluefin/b.bst"])
        self.assertEqual(
            parsed,
            {
                "bluefin/a.bst": ["/usr/bin/ghostty"],
                "bluefin/b.bst": ["/etc/bluefin/config"],
            },
        )


if __name__ == "__main__":
    unittest.main()
