#!/usr/bin/env python3
"""Unit tests for .github/scripts/sbom_diff.py.

Covers the version-string normalisers (clean_version, short_sha,
best_version), SPDX package-map construction including the linux kernel
SPDXID resolution and dedup rules (load_pkg_map), the notable-chip
extraction (extract_notable), the added/changed/removed diff
(diff_sboms), and the main() CLI contract.
"""
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

REPOSITORY = Path(__file__).resolve().parents[1]
MODULE_PATH = REPOSITORY / ".github" / "scripts" / "sbom_diff.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("sbom_diff_under_test", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


sbom_diff = _load_module()

SHA40 = "965cd7b99b04faf55819606178a5e8233cfd8b9e"


def _sbom(packages):
    return {"spdxVersion": "SPDX-2.3", "packages": packages}


def _pkg(name, version="", spdxid=None):
    return {
        "name": name,
        "versionInfo": version,
        "SPDXID": spdxid if spdxid is not None else f"SPDXRef-{name}",
    }


def _write_sbom(directory, filename, packages):
    path = Path(directory) / filename
    path.write_text(json.dumps(_sbom(packages)), encoding="utf-8")
    return str(path)


class CleanVersionTests(unittest.TestCase):
    def test_returns_none_for_empty_input(self):
        self.assertIsNone(sbom_diff.clean_version(None))
        self.assertIsNone(sbom_diff.clean_version(""))

    def test_passes_through_semver(self):
        self.assertEqual(sbom_diff.clean_version("1.15.2"), "1.15.2")

    def test_strips_surrounding_whitespace(self):
        self.assertEqual(sbom_diff.clean_version("  6.19.14\n"), "6.19.14")

    def test_strips_git_describe_suffix(self):
        raw = "2.0.0-rc.2-9-gc74dc52ac1b796557a6ef3eb18b8884a0c722324"
        self.assertEqual(sbom_diff.clean_version(raw), "2.0.0-rc.2")

    def test_returns_none_for_bare_40_char_sha(self):
        self.assertIsNone(sbom_diff.clean_version(SHA40))

    def test_returns_none_for_long_content_hash(self):
        self.assertIsNone(sbom_diff.clean_version("a" * 32 + "/167"))

    def test_keeps_short_hex_that_is_not_a_sha(self):
        self.assertEqual(sbom_diff.clean_version("abc123"), "abc123")


class ShortShaTests(unittest.TestCase):
    def test_returns_first_eight_chars_of_bare_sha(self):
        self.assertEqual(sbom_diff.short_sha(SHA40), SHA40[:8])

    def test_tolerates_surrounding_whitespace(self):
        self.assertEqual(sbom_diff.short_sha(f"  {SHA40}  "), SHA40[:8])

    def test_returns_none_for_non_sha(self):
        self.assertIsNone(sbom_diff.short_sha("1.2.3"))
        self.assertIsNone(sbom_diff.short_sha(None))
        self.assertIsNone(sbom_diff.short_sha(""))


class BestVersionTests(unittest.TestCase):
    def test_prefers_clean_version(self):
        self.assertEqual(sbom_diff.best_version("1.2.3"), "1.2.3")

    def test_falls_back_to_short_sha(self):
        self.assertEqual(sbom_diff.best_version(SHA40), SHA40[:8])

    def test_returns_none_when_nothing_usable(self):
        self.assertIsNone(sbom_diff.best_version(""))
        self.assertIsNone(sbom_diff.best_version("a" * 32 + "/167"))


class LoadPkgMapTests(unittest.TestCase):
    def _load(self, packages):
        with tempfile.TemporaryDirectory() as tmp:
            return sbom_diff.load_pkg_map(_write_sbom(tmp, "sbom.json", packages))

    def test_builds_name_to_version_map(self):
        pkgs = self._load([_pkg("mesa", "25.0.3"), _pkg("podman", "5.4.0")])
        self.assertEqual(pkgs["mesa"]["ver"], "25.0.3")
        self.assertEqual(pkgs["podman"]["ver"], "5.4.0")

    def test_records_spdxid(self):
        pkgs = self._load([_pkg("mesa", "25.0.3", spdxid="SPDXRef-mesa.bst")])
        self.assertEqual(pkgs["mesa"]["spdxid"], "SPDXRef-mesa.bst")

    def test_missing_version_becomes_none(self):
        pkgs = self._load([_pkg("mesa")])
        self.assertIsNone(pkgs["mesa"]["ver"])

    def test_handles_sbom_without_packages_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "empty.json"
            path.write_text(json.dumps({"spdxVersion": "SPDX-2.3"}), encoding="utf-8")
            self.assertEqual(sbom_diff.load_pkg_map(str(path)), {})

    def test_duplicate_prefers_semver_over_sha(self):
        pkgs = self._load([_pkg("gum", SHA40), _pkg("gum", "0.16.2")])
        self.assertEqual(pkgs["gum"]["ver"], "0.16.2")

    def test_duplicate_prefers_semver_regardless_of_order(self):
        pkgs = self._load([_pkg("gum", "0.16.2"), _pkg("gum", SHA40)])
        self.assertEqual(pkgs["gum"]["ver"], "0.16.2")

    def test_duplicate_prefers_any_version_over_none(self):
        pkgs = self._load([_pkg("gum"), _pkg("gum", SHA40)])
        self.assertEqual(pkgs["gum"]["ver"], SHA40[:8])

    def test_first_semver_wins_over_later_semver(self):
        pkgs = self._load([_pkg("gum", "0.16.2"), _pkg("gum", "0.15.0")])
        self.assertEqual(pkgs["gum"]["ver"], "0.16.2")

    def test_kernel_prefers_components_linux_bst_entry(self):
        pkgs = self._load([
            _pkg("linux", "6.0.0", spdxid="SPDXRef-vendored-linux.bst"),
            _pkg("linux", "6.19.14", spdxid="SPDXRef-components-linux.bst"),
        ])
        self.assertEqual(pkgs["linux"]["ver"], "6.19.14")

    def test_kernel_prefers_semver_among_filtered_candidates(self):
        pkgs = self._load([
            _pkg("linux", SHA40, spdxid="SPDXRef-components-linux.bst-a"),
            _pkg("linux", "6.19.14", spdxid="SPDXRef-components-linux.bst-b"),
        ])
        self.assertEqual(pkgs["linux"]["ver"], "6.19.14")

    def test_kernel_falls_back_when_no_spdxid_match(self):
        pkgs = self._load([_pkg("linux", "6.1.0", spdxid="SPDXRef-other")])
        self.assertEqual(pkgs["linux"]["ver"], "6.1.0")

    def test_no_kernel_key_when_no_linux_package(self):
        pkgs = self._load([_pkg("mesa", "25.0.3")])
        self.assertNotIn("linux", pkgs)


class ExtractNotableTests(unittest.TestCase):
    def test_returns_notable_packages_in_declared_order(self):
        curr = {
            "mesa": {"ver": "25.0.3", "spdxid": ""},
            "linux": {"ver": "6.19.14", "spdxid": ""},
        }
        names = [e["name"] for e in sbom_diff.extract_notable(curr, None)]
        self.assertEqual(names, ["Kernel", "Mesa"])

    def test_skips_packages_absent_from_current_map(self):
        result = sbom_diff.extract_notable({"mesa": {"ver": "25.0.3", "spdxid": ""}}, None)
        self.assertEqual([e["name"] for e in result], ["Mesa"])

    def test_uses_display_label_not_sbom_name(self):
        result = sbom_diff.extract_notable(
            {"uutils-coreutils": {"ver": "0.1.0", "spdxid": ""}}, None)
        self.assertEqual(result[0]["name"], "uutils")

    def test_unknown_version_placeholder(self):
        result = sbom_diff.extract_notable({"mesa": {"ver": None, "spdxid": ""}}, None)
        self.assertEqual(result[0]["version"], "(unknown)")

    def test_marks_changed_when_previous_differs(self):
        curr = {"mesa": {"ver": "25.0.3", "spdxid": ""}}
        prev = {"mesa": {"ver": "25.0.2", "spdxid": ""}}
        entry = sbom_diff.extract_notable(curr, prev)[0]
        self.assertTrue(entry["changed"])
        self.assertEqual(entry["prev"], "25.0.2")

    def test_not_changed_when_previous_matches(self):
        curr = {"mesa": {"ver": "25.0.3", "spdxid": ""}}
        prev = {"mesa": {"ver": "25.0.3", "spdxid": ""}}
        entry = sbom_diff.extract_notable(curr, prev)[0]
        self.assertFalse(entry["changed"])
        self.assertIsNone(entry["prev"])

    def test_not_changed_when_package_is_new(self):
        curr = {"mesa": {"ver": "25.0.3", "spdxid": ""}}
        entry = sbom_diff.extract_notable(curr, {})[0]
        self.assertFalse(entry["changed"])
        self.assertIsNone(entry["prev"])

    def test_kernel_chip_survives_spdxid_drift(self):
        curr = {"linux": {"ver": "6.19.14", "spdxid": "SPDXRef-totally-renamed"}}
        result = sbom_diff.extract_notable(curr, None)
        self.assertEqual(result[0]["name"], "Kernel")
        self.assertEqual(result[0]["version"], "6.19.14")


class DiffSbomsTests(unittest.TestCase):
    def test_detects_added_changed_and_removed(self):
        curr = {
            "mesa": {"ver": "25.0.3", "spdxid": ""},
            "nethogs": {"ver": "0.8.7", "spdxid": ""},
        }
        prev = {
            "mesa": {"ver": "25.0.2", "spdxid": ""},
            "cowsay": {"ver": "3.8.4", "spdxid": ""},
        }
        diff = sbom_diff.diff_sboms(curr, prev)
        self.assertEqual(diff["changed"], [{"name": "mesa", "prev": "25.0.2", "curr": "25.0.3"}])
        self.assertEqual(diff["added"], [{"name": "nethogs", "version": "0.8.7"}])
        self.assertEqual(diff["removed"], [{"name": "cowsay", "version": "3.8.4"}])
        self.assertEqual(
            (diff["changed_count"], diff["added_count"], diff["removed_count"]), (1, 1, 1))

    def test_identical_maps_produce_empty_diff(self):
        pkgs = {"mesa": {"ver": "25.0.3", "spdxid": ""}}
        diff = sbom_diff.diff_sboms(pkgs, dict(pkgs))
        self.assertEqual(
            (diff["changed_count"], diff["added_count"], diff["removed_count"]), (0, 0, 0))

    def test_results_are_sorted_by_name(self):
        curr = {n: {"ver": "1", "spdxid": ""} for n in ("zlib", "acl", "mesa")}
        diff = sbom_diff.diff_sboms(curr, {})
        self.assertEqual([e["name"] for e in diff["added"]], ["acl", "mesa", "zlib"])

    def test_unknown_placeholder_for_versionless_added_and_removed(self):
        diff = sbom_diff.diff_sboms(
            {"mesa": {"ver": None, "spdxid": ""}}, {"cowsay": {"ver": None, "spdxid": ""}})
        self.assertEqual(diff["added"][0]["version"], "(unknown)")
        self.assertEqual(diff["removed"][0]["version"], "(unknown)")

    def test_version_becoming_none_is_not_reported_as_changed(self):
        diff = sbom_diff.diff_sboms(
            {"mesa": {"ver": None, "spdxid": ""}}, {"mesa": {"ver": "25.0.2", "spdxid": ""}})
        self.assertEqual(diff["changed"], [])
        self.assertEqual(diff["added"], [])
        self.assertEqual(diff["removed"], [])


class MainTests(unittest.TestCase):
    def _run(self, argv):
        buf = io.StringIO()
        err = io.StringIO()
        with mock.patch.object(sys, "argv", ["sbom_diff.py", *argv]), \
                redirect_stdout(buf), redirect_stderr(err):
            sbom_diff.main()
        return buf.getvalue()

    def test_writes_output_without_previous_sbom(self):
        with tempfile.TemporaryDirectory() as tmp:
            curr = _write_sbom(tmp, "curr.json", [_pkg("mesa", "25.0.3")])
            out = str(Path(tmp) / "versions.json")
            self._run(["--current", curr, "--output", out])
            data = json.loads(Path(out).read_text(encoding="utf-8"))

        self.assertFalse(data["has_prev"])
        self.assertEqual(data["notable"], [
            {"name": "Mesa", "version": "25.0.3", "prev": None, "changed": False}])
        self.assertEqual(data["diff"]["changed_count"], 0)
        self.assertEqual(data["diff"]["added"], [])

    def test_writes_full_diff_with_previous_sbom(self):
        with tempfile.TemporaryDirectory() as tmp:
            curr = _write_sbom(tmp, "curr.json", [_pkg("mesa", "25.0.3")])
            prev = _write_sbom(tmp, "prev.json", [_pkg("mesa", "25.0.2")])
            out = str(Path(tmp) / "versions.json")
            self._run(["--current", curr, "--previous", prev, "--output", out])
            data = json.loads(Path(out).read_text(encoding="utf-8"))

        self.assertTrue(data["has_prev"])
        self.assertTrue(data["notable"][0]["changed"])
        self.assertEqual(data["diff"]["changed_count"], 1)

    def test_missing_previous_path_is_tolerated(self):
        with tempfile.TemporaryDirectory() as tmp:
            curr = _write_sbom(tmp, "curr.json", [_pkg("mesa", "25.0.3")])
            out = str(Path(tmp) / "versions.json")
            self._run([
                "--current", curr,
                "--previous", str(Path(tmp) / "nope.json"),
                "--output", out,
            ])
            data = json.loads(Path(out).read_text(encoding="utf-8"))

        self.assertFalse(data["has_prev"])
        self.assertEqual(data["diff"]["removed_count"], 0)

    def test_missing_current_sbom_exits_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(SystemExit) as ctx:
                self._run([
                    "--current", str(Path(tmp) / "nope.json"),
                    "--output", str(Path(tmp) / "versions.json"),
                ])
        self.assertEqual(ctx.exception.code, 1)

    def test_output_json_is_indented(self):
        with tempfile.TemporaryDirectory() as tmp:
            curr = _write_sbom(tmp, "curr.json", [_pkg("mesa", "25.0.3")])
            out = str(Path(tmp) / "versions.json")
            self._run(["--current", curr, "--output", out])
            text = Path(out).read_text(encoding="utf-8")
        self.assertIn('\n  "notable": [', text)


if __name__ == "__main__":
    unittest.main()
