#!/usr/bin/env python3
"""Unit tests for .github/scripts/sbom_diff.py.

Covers the pure version helpers (clean_version, short_sha, best_version),
SPDX package-map construction with kernel SPDXID resolution (load_pkg_map),
notable-chip extraction (extract_notable), the added/changed/removed
classifier (diff_sboms) and the main() CLI contract.
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
MODULE_PATH = REPOSITORY / ".github" / "scripts" / "sbom_diff.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("sbom_diff_under_test", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


sbom_diff = _load_module()


def _pkg(name, version, spdxid=""):
    return {"name": name, "versionInfo": version, "SPDXID": spdxid}


def _write_sbom(directory: Path, filename: str, packages: list[dict]) -> Path:
    path = directory / filename
    path.write_text(json.dumps({"packages": packages}), encoding="utf-8")
    return path


class CleanVersionTests(unittest.TestCase):
    def test_returns_none_for_empty_input(self) -> None:
        self.assertIsNone(sbom_diff.clean_version(None))
        self.assertIsNone(sbom_diff.clean_version(""))

    def test_preserves_plain_semver(self) -> None:
        self.assertEqual(sbom_diff.clean_version("1.15.2"), "1.15.2")

    def test_strips_surrounding_whitespace(self) -> None:
        self.assertEqual(sbom_diff.clean_version("  6.19.14 \n"), "6.19.14")

    def test_strips_git_describe_suffix(self) -> None:
        raw = "2.0.0-rc.2-9-gc74dc52ac1b796557a6ef3eb18b8884a0c722324"
        self.assertEqual(sbom_diff.clean_version(raw), "2.0.0-rc.2")

    def test_returns_none_for_bare_forty_char_sha(self) -> None:
        self.assertIsNone(
            sbom_diff.clean_version("965cd7b99b04faf55819606178a5e8233cfd8b9e")
        )

    def test_returns_none_for_long_content_hash(self) -> None:
        self.assertIsNone(sbom_diff.clean_version("a" * 32 + "/167"))


class ShortShaTests(unittest.TestCase):
    def test_shortens_bare_sha_to_eight_chars(self) -> None:
        self.assertEqual(
            sbom_diff.short_sha("965cd7b99b04faf55819606178a5e8233cfd8b9e"),
            "965cd7b9",
        )

    def test_tolerates_surrounding_whitespace(self) -> None:
        self.assertEqual(
            sbom_diff.short_sha(" 965cd7b99b04faf55819606178a5e8233cfd8b9e "),
            "965cd7b9",
        )

    def test_returns_none_for_non_sha(self) -> None:
        self.assertIsNone(sbom_diff.short_sha("1.15.2"))
        self.assertIsNone(sbom_diff.short_sha(None))
        self.assertIsNone(sbom_diff.short_sha("965cd7b9"))


class BestVersionTests(unittest.TestCase):
    def test_prefers_clean_semver(self) -> None:
        self.assertEqual(sbom_diff.best_version("1.15.2"), "1.15.2")

    def test_falls_back_to_short_sha(self) -> None:
        self.assertEqual(
            sbom_diff.best_version("965cd7b99b04faf55819606178a5e8233cfd8b9e"),
            "965cd7b9",
        )

    def test_returns_none_when_nothing_usable(self) -> None:
        self.assertIsNone(sbom_diff.best_version(""))
        self.assertIsNone(sbom_diff.best_version("a" * 32 + "/167"))


class LoadPkgMapTests(unittest.TestCase):
    def load(self, packages: list[dict]) -> dict:
        with tempfile.TemporaryDirectory() as tempdir:
            path = _write_sbom(Path(tempdir), "sbom.json", packages)
            return sbom_diff.load_pkg_map(str(path))

    def test_builds_name_to_version_map(self) -> None:
        pkgs = self.load([_pkg("mesa", "25.1.0", "SPDXRef-mesa")])
        self.assertEqual(pkgs["mesa"], {"ver": "25.1.0", "spdxid": "SPDXRef-mesa"})

    def test_empty_sbom_yields_empty_map(self) -> None:
        self.assertEqual(self.load([]), {})

    def test_duplicate_name_prefers_semver_over_sha(self) -> None:
        pkgs = self.load([
            _pkg("podman", "965cd7b99b04faf55819606178a5e8233cfd8b9e", "SPDXRef-a"),
            _pkg("podman", "5.6.2", "SPDXRef-b"),
        ])
        self.assertEqual(pkgs["podman"]["ver"], "5.6.2")
        self.assertEqual(pkgs["podman"]["spdxid"], "SPDXRef-b")

    def test_duplicate_name_keeps_first_semver(self) -> None:
        pkgs = self.load([
            _pkg("podman", "5.6.2", "SPDXRef-a"),
            _pkg("podman", "4.0.0", "SPDXRef-b"),
        ])
        self.assertEqual(pkgs["podman"]["ver"], "5.6.2")

    def test_duplicate_name_fills_missing_version(self) -> None:
        pkgs = self.load([
            _pkg("gum", "a" * 32 + "/167", "SPDXRef-a"),
            _pkg("gum", "0.14.5", "SPDXRef-b"),
        ])
        self.assertEqual(pkgs["gum"]["ver"], "0.14.5")

    def test_kernel_prefers_components_linux_spdxid(self) -> None:
        pkgs = self.load([
            _pkg("linux", "6.0.0", "SPDXRef-other-linux"),
            _pkg("linux", "6.19.14", "SPDXRef-components-linux.bst"),
        ])
        self.assertEqual(pkgs["linux"]["ver"], "6.19.14")
        self.assertIn("components-linux.bst", pkgs["linux"]["spdxid"])

    def test_kernel_prefers_semver_among_matching_spdxids(self) -> None:
        pkgs = self.load([
            _pkg(
                "linux",
                "965cd7b99b04faf55819606178a5e8233cfd8b9e",
                "SPDXRef-components-linux.bst-1",
            ),
            _pkg("linux", "6.19.14", "SPDXRef-components-linux.bst-2"),
        ])
        self.assertEqual(pkgs["linux"]["ver"], "6.19.14")

    def test_kernel_falls_back_when_no_spdxid_matches(self) -> None:
        pkgs = self.load([_pkg("linux", "6.19.14", "SPDXRef-unexpected")])
        self.assertEqual(pkgs["linux"]["ver"], "6.19.14")

    def test_no_linux_package_leaves_key_absent(self) -> None:
        pkgs = self.load([_pkg("mesa", "25.1.0", "SPDXRef-mesa")])
        self.assertNotIn("linux", pkgs)


class ExtractNotableTests(unittest.TestCase):
    def test_orders_entries_by_notable_table(self) -> None:
        curr = {
            "mesa": {"ver": "25.1.0", "spdxid": ""},
            "linux": {"ver": "6.19.14", "spdxid": "SPDXRef-components-linux.bst"},
        }
        names = [e["name"] for e in sbom_diff.extract_notable(curr, None)]
        self.assertEqual(names, ["Kernel", "Mesa"])

    def test_skips_packages_absent_from_current_map(self) -> None:
        self.assertEqual(sbom_diff.extract_notable({}, None), [])

    def test_kernel_kept_even_when_spdxid_does_not_match_filter(self) -> None:
        curr = {"linux": {"ver": "6.19.14", "spdxid": "SPDXRef-drifted-name"}}
        notable = sbom_diff.extract_notable(curr, None)
        self.assertEqual(notable[0]["name"], "Kernel")
        self.assertEqual(notable[0]["version"], "6.19.14")

    def test_unknown_version_placeholder(self) -> None:
        curr = {"gum": {"ver": None, "spdxid": ""}}
        self.assertEqual(sbom_diff.extract_notable(curr, None)[0]["version"], "(unknown)")

    def test_marks_changed_when_previous_version_differs(self) -> None:
        curr = {"podman": {"ver": "5.6.2", "spdxid": ""}}
        prev = {"podman": {"ver": "5.6.1", "spdxid": ""}}
        entry = sbom_diff.extract_notable(curr, prev)[0]
        self.assertTrue(entry["changed"])
        self.assertEqual(entry["prev"], "5.6.1")

    def test_unchanged_when_previous_version_matches(self) -> None:
        curr = {"podman": {"ver": "5.6.2", "spdxid": ""}}
        prev = {"podman": {"ver": "5.6.2", "spdxid": ""}}
        entry = sbom_diff.extract_notable(curr, prev)[0]
        self.assertFalse(entry["changed"])
        self.assertIsNone(entry["prev"])

    def test_unchanged_when_package_missing_from_previous(self) -> None:
        curr = {"podman": {"ver": "5.6.2", "spdxid": ""}}
        entry = sbom_diff.extract_notable(curr, {"mesa": {"ver": "1", "spdxid": ""}})[0]
        self.assertFalse(entry["changed"])


class DiffSbomsTests(unittest.TestCase):
    def test_classifies_added_changed_and_removed(self) -> None:
        curr = {
            "kept":    {"ver": "1.0", "spdxid": ""},
            "bumped":  {"ver": "2.0", "spdxid": ""},
            "fresh":   {"ver": "0.1", "spdxid": ""},
        }
        prev = {
            "kept":    {"ver": "1.0", "spdxid": ""},
            "bumped":  {"ver": "1.9", "spdxid": ""},
            "dropped": {"ver": "3.0", "spdxid": ""},
        }
        diff = sbom_diff.diff_sboms(curr, prev)
        self.assertEqual(diff["added"], [{"name": "fresh", "version": "0.1"}])
        self.assertEqual(diff["removed"], [{"name": "dropped", "version": "3.0"}])
        self.assertEqual(
            diff["changed"], [{"name": "bumped", "prev": "1.9", "curr": "2.0"}]
        )
        self.assertEqual(
            (diff["added_count"], diff["changed_count"], diff["removed_count"]),
            (1, 1, 1),
        )

    def test_identical_maps_produce_empty_diff(self) -> None:
        pkgs = {"mesa": {"ver": "25.1.0", "spdxid": ""}}
        diff = sbom_diff.diff_sboms(pkgs, dict(pkgs))
        self.assertEqual(diff["changed_count"], 0)
        self.assertEqual(diff["added_count"], 0)
        self.assertEqual(diff["removed_count"], 0)

    def test_results_are_sorted_by_name(self) -> None:
        curr = {"zeta": {"ver": "1", "spdxid": ""}, "alpha": {"ver": "1", "spdxid": ""}}
        diff = sbom_diff.diff_sboms(curr, {})
        self.assertEqual([e["name"] for e in diff["added"]], ["alpha", "zeta"])

    def test_unknown_version_placeholder_for_added_and_removed(self) -> None:
        diff = sbom_diff.diff_sboms(
            {"added": {"ver": None, "spdxid": ""}},
            {"gone": {"ver": None, "spdxid": ""}},
        )
        self.assertEqual(diff["added"][0]["version"], "(unknown)")
        self.assertEqual(diff["removed"][0]["version"], "(unknown)")

    def test_missing_version_on_both_sides_is_not_a_change(self) -> None:
        curr = {"mystery": {"ver": None, "spdxid": ""}}
        prev = {"mystery": {"ver": "1.0", "spdxid": ""}}
        self.assertEqual(sbom_diff.diff_sboms(curr, prev)["changed"], [])


class MainTests(unittest.TestCase):
    def run_main(self, argv: list[str]) -> str:
        buffer = io.StringIO()
        with mock.patch.object(sys, "argv", ["sbom_diff.py", *argv]):
            with redirect_stdout(buffer):
                sbom_diff.main()
        return buffer.getvalue()

    def test_writes_versions_json_without_previous_sbom(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            workspace = Path(tempdir)
            current = _write_sbom(workspace, "curr.json", [
                _pkg("linux", "6.19.14", "SPDXRef-components-linux.bst"),
                _pkg("mesa", "25.1.0", "SPDXRef-mesa"),
            ])
            output = workspace / "versions.json"
            self.run_main(["--current", str(current), "--output", str(output)])

            data = json.loads(output.read_text(encoding="utf-8"))
            self.assertFalse(data["has_prev"])
            self.assertEqual(
                [e["name"] for e in data["notable"]], ["Kernel", "Mesa"]
            )
            self.assertEqual(data["diff"]["changed_count"], 0)
            self.assertEqual(data["diff"]["changed"], [])

    def test_computes_diff_when_previous_sbom_given(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            workspace = Path(tempdir)
            current = _write_sbom(workspace, "curr.json", [
                _pkg("mesa", "25.1.0", "SPDXRef-mesa"),
                _pkg("gum", "0.14.5", "SPDXRef-gum"),
            ])
            previous = _write_sbom(workspace, "prev.json", [
                _pkg("mesa", "25.0.0", "SPDXRef-mesa"),
            ])
            output = workspace / "versions.json"
            self.run_main([
                "--current", str(current),
                "--previous", str(previous),
                "--output", str(output),
            ])

            data = json.loads(output.read_text(encoding="utf-8"))
            self.assertTrue(data["has_prev"])
            self.assertEqual(data["diff"]["changed_count"], 1)
            self.assertEqual(data["diff"]["added_count"], 1)
            mesa = next(e for e in data["notable"] if e["name"] == "Mesa")
            self.assertTrue(mesa["changed"])
            self.assertEqual(mesa["prev"], "25.0.0")

    def test_missing_previous_path_is_tolerated(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            workspace = Path(tempdir)
            current = _write_sbom(workspace, "curr.json",
                                  [_pkg("mesa", "25.1.0", "SPDXRef-mesa")])
            output = workspace / "versions.json"
            self.run_main([
                "--current", str(current),
                "--previous", str(workspace / "does-not-exist.json"),
                "--output", str(output),
            ])
            self.assertFalse(json.loads(output.read_text(encoding="utf-8"))["has_prev"])

    def test_missing_current_sbom_exits_nonzero(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            workspace = Path(tempdir)
            with self.assertRaises(SystemExit) as caught:
                self.run_main([
                    "--current", str(workspace / "missing.json"),
                    "--output", str(workspace / "versions.json"),
                ])
            self.assertEqual(caught.exception.code, 1)


if __name__ == "__main__":
    unittest.main()
