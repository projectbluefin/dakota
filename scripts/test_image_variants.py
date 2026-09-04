#!/usr/bin/env python3
"""Unit coverage for .github/scripts/image_variants.py.

scripts/test_check_publish_workflow.py exercises this module only through the
real .github/image-variants.json (happy path) and a handful of mutated
declarations driven through the checker subprocess. These tests drive the
module directly with synthetic inputs so the error branches, the YAML scalar
parser, and the CLI entry point are covered.
"""

import io
import json
import contextlib
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPOSITORY / ".github/scripts"))

import image_variants  # noqa: E402


def declaration(**overrides) -> dict:
    """A minimal, internally consistent declaration."""
    base = {
        "roles": {
            "publish": {
                "derived": True,
                "consumer": ".github/workflows/publish.yml (publish-image)",
                "fields": ["variant", "image", "continue"],
            },
        },
        "variants": [
            {
                "variant": "base",
                "image": "dakota",
                "continue": False,
                "roles": {"publish": {}},
            },
        ],
    }
    base.update(overrides)
    return base


class LoadTests(unittest.TestCase):
    def test_missing_file_reports_the_path(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            path = Path(tempdir) / "absent.json"
            with self.assertRaises(image_variants.DeclarationError) as caught:
                image_variants.load(path)
        self.assertIn("is missing", str(caught.exception))

    def test_invalid_json_reports_the_decode_error(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            path = Path(tempdir) / "broken.json"
            path.write_text("{not json")
            with self.assertRaises(image_variants.DeclarationError) as caught:
                image_variants.load(path)
        self.assertIn("not valid JSON", str(caught.exception))

    def test_valid_json_round_trips(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            path = Path(tempdir) / "ok.json"
            path.write_text(json.dumps(declaration()))
            self.assertEqual(image_variants.load(path), declaration())


class ValidateTests(unittest.TestCase):
    def assert_error(self, decl: dict, fragment: str) -> None:
        errors = image_variants.validate(decl)
        self.assertTrue(
            any(fragment in error for error in errors),
            f"expected an error containing {fragment!r}, got {errors}",
        )

    def test_minimal_declaration_is_clean(self) -> None:
        self.assertEqual(image_variants.validate(declaration()), [])

    def test_missing_roles_short_circuits(self) -> None:
        decl = declaration()
        del decl["roles"]
        self.assertEqual(
            image_variants.validate(decl),
            ["image-variants.json must define a non-empty 'roles' object"],
        )

    def test_empty_roles_short_circuits(self) -> None:
        self.assertEqual(
            image_variants.validate(declaration(roles={})),
            ["image-variants.json must define a non-empty 'roles' object"],
        )

    def test_variants_must_be_a_non_empty_list(self) -> None:
        for value in ([], {}, None):
            with self.subTest(variants=value):
                self.assertEqual(
                    image_variants.validate(declaration(variants=value)),
                    ["image-variants.json must define a non-empty 'variants' list"],
                )

    def test_role_must_declare_fields_derived_and_consumer(self) -> None:
        decl = declaration(roles={"publish": {}})
        errors = image_variants.validate(decl)
        self.assertTrue(any("non-empty 'fields' list" in e for e in errors))
        self.assertTrue(any("boolean 'derived'" in e for e in errors))
        self.assertTrue(any("'consumer' workflow" in e for e in errors))

    def test_derived_must_be_a_boolean_not_a_truthy_string(self) -> None:
        decl = declaration()
        decl["roles"]["publish"]["derived"] = "true"
        self.assert_error(decl, "boolean 'derived'")

    def test_variant_without_a_name_is_rejected(self) -> None:
        decl = declaration(variants=[{"image": "dakota", "roles": {"publish": {}}}])
        self.assert_error(decl, "must declare a 'variant' name")

    def test_duplicate_variant_name_is_rejected(self) -> None:
        decl = declaration()
        decl["variants"].append(
            {"variant": "base", "image": "dakota-other", "roles": {"publish": {}}}
        )
        self.assert_error(decl, "declared more than once")

    def test_variant_without_an_image_is_rejected(self) -> None:
        decl = declaration()
        del decl["variants"][0]["image"]
        self.assert_error(decl, "must declare its published 'image'")

    def test_duplicate_image_is_rejected(self) -> None:
        decl = declaration()
        decl["variants"].append(
            {"variant": "other", "image": "dakota", "roles": {"publish": {}}}
        )
        self.assert_error(decl, "claimed by more than one variant")

    def test_variant_roles_must_be_an_object(self) -> None:
        decl = declaration()
        decl["variants"][0]["roles"] = ["publish"]
        self.assert_error(decl, "must declare a 'roles' object")

    def test_membership_must_be_explicit_for_every_role(self) -> None:
        decl = declaration()
        decl["roles"]["sbom"] = {
            "derived": True,
            "consumer": "publish.yml (publish-sbom)",
            "fields": ["variant"],
        }
        self.assert_error(decl, "does not declare membership for role 'sbom'")

    def test_unknown_role_membership_is_rejected(self) -> None:
        decl = declaration()
        decl["variants"][0]["roles"]["ghost"] = {}
        self.assert_error(decl, "declares unknown role 'ghost'")

    def test_membership_must_be_an_object(self) -> None:
        decl = declaration()
        decl["variants"][0]["roles"]["publish"] = True
        self.assert_error(decl, "role 'publish' must be an object")

    def test_blank_exclusion_reason_is_rejected(self) -> None:
        for reason in ("", "   "):
            with self.subTest(reason=reason):
                decl = declaration()
                decl["variants"][0]["roles"]["publish"] = {"excluded": reason}
                self.assert_error(decl, "without a reason")

    def test_exclusion_with_a_reason_is_accepted(self) -> None:
        decl = declaration()
        decl["variants"][0]["roles"]["publish"] = {"excluded": "no SBOM producer"}
        self.assertEqual(image_variants.validate(decl), [])


class MatrixForTests(unittest.TestCase):
    def test_unknown_role_raises(self) -> None:
        with self.assertRaises(image_variants.DeclarationError):
            image_variants.matrix_for(declaration(), "nope")

    def test_projection_is_restricted_to_declared_fields(self) -> None:
        decl = declaration()
        decl["variants"][0]["internal_note"] = "not a matrix field"
        self.assertEqual(
            image_variants.matrix_for(decl, "publish"),
            [{"variant": "base", "image": "dakota", "continue": False}],
        )

    def test_absent_fields_are_omitted_rather_than_defaulted(self) -> None:
        decl = declaration()
        del decl["variants"][0]["continue"]
        self.assertEqual(
            image_variants.matrix_for(decl, "publish"),
            [{"variant": "base", "image": "dakota"}],
        )

    def test_role_local_values_override_variant_level_metadata(self) -> None:
        decl = declaration()
        decl["variants"][0]["roles"]["publish"] = {"continue": True}
        self.assertEqual(
            image_variants.matrix_for(decl, "publish"),
            [{"variant": "base", "image": "dakota", "continue": True}],
        )

    def test_excluded_and_undeclared_variants_are_dropped(self) -> None:
        decl = declaration()
        decl["variants"].append(
            {
                "variant": "gaming",
                "image": "dakota-gaming",
                "roles": {"publish": {"excluded": "gaming ships no SBOM"}},
            }
        )
        decl["variants"].append(
            {"variant": "orphan", "image": "dakota-orphan", "roles": {}}
        )
        self.assertEqual(
            [entry["variant"] for entry in image_variants.matrix_for(decl, "publish")],
            ["base"],
        )


class ScalarTests(unittest.TestCase):
    def test_bare_booleans_become_booleans(self) -> None:
        self.assertIs(image_variants._scalar(" true "), True)
        self.assertIs(image_variants._scalar("false"), False)

    def test_quoting_is_significant(self) -> None:
        self.assertEqual(image_variants._scalar("'true'"), "true")
        self.assertEqual(image_variants._scalar('"false"'), "false")

    def test_plain_text_is_returned_stripped(self) -> None:
        self.assertEqual(image_variants._scalar("  dakota-nvidia  "), "dakota-nvidia")

    def test_mismatched_quotes_are_not_stripped(self) -> None:
        self.assertEqual(image_variants._scalar("'dakota\""), "'dakota\"")


WORKFLOW = textwrap.dedent(
    """\
    jobs:
      publish-image:
        strategy:
          matrix:
            include:
              # the base image
              - variant: base
                image: dakota
                continue: false
              - variant: nvidia
                image: 'true'
                continue: true
        steps:
          - run: echo hi

      other-job:
        steps:
          - run: echo bye
    """
)


def workflow_declaration() -> dict:
    """A declaration whose publish matrix equals WORKFLOW's inline matrix."""
    decl = declaration()
    decl["variants"].append(
        {
            "variant": "nvidia",
            "image": "true",
            "continue": True,
            "roles": {"publish": {}},
        }
    )
    return decl


class ParseWorkflowMatrixTests(unittest.TestCase):
    def test_absent_job_returns_none(self) -> None:
        self.assertIsNone(image_variants.parse_workflow_matrix(WORKFLOW, "ghost"))

    def test_job_without_an_include_block_returns_none(self) -> None:
        self.assertIsNone(image_variants.parse_workflow_matrix(WORKFLOW, "other-job"))

    def test_entries_are_split_on_the_list_dash(self) -> None:
        self.assertEqual(
            image_variants.parse_workflow_matrix(WORKFLOW, "publish-image"),
            [
                {"variant": "base", "image": "dakota", "continue": False},
                {"variant": "nvidia", "image": "true", "continue": True},
            ],
        )

    def test_parsing_stops_at_the_first_dedent(self) -> None:
        # `steps:` sits at a shallower indent than the include entries, so it
        # must not be absorbed into the last matrix entry.
        entries = image_variants.parse_workflow_matrix(WORKFLOW, "publish-image")
        self.assertNotIn("steps", entries[-1])

    def test_comments_and_blank_lines_are_ignored(self) -> None:
        entries = image_variants.parse_workflow_matrix(WORKFLOW, "publish-image")
        self.assertEqual(len(entries), 2)


class CheckWorkflowDriftTests(unittest.TestCase):
    def test_agreement_reports_no_errors(self) -> None:
        decl = workflow_declaration()
        self.assertEqual(image_variants.validate(decl), [])
        self.assertEqual(
            image_variants.check_workflow_drift(
                decl, WORKFLOW, {"publish": "publish-image"}
            ),
            [],
        )

    def test_unparseable_job_is_reported_not_silently_skipped(self) -> None:
        errors = image_variants.check_workflow_drift(
            workflow_declaration(), WORKFLOW, {"publish": "missing-job"}
        )
        self.assertEqual(len(errors), 1)
        self.assertIn("could not parse the 'missing-job' matrix", errors[0])

    def test_drift_names_both_sides(self) -> None:
        drifted = WORKFLOW.replace("image: dakota\n", "image: dakota-renamed\n", 1)
        errors = image_variants.check_workflow_drift(
            workflow_declaration(), drifted, {"publish": "publish-image"}
        )
        self.assertEqual(len(errors), 1)
        self.assertIn("dakota-renamed", errors[0])
        self.assertIn("declaration:", errors[0])


class MainTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        root = Path(self.tempdir.name)
        self.decl_path = root / "image-variants.json"
        self.decl_path.write_text(json.dumps(workflow_declaration()))
        self.workflow_path = root / "publish.yml"
        self.workflow_path.write_text(WORKFLOW)

    def run_main(self, argv: list[str]) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = image_variants.main(argv)
        return code, out.getvalue(), err.getvalue()

    def test_requires_role_or_check(self) -> None:
        with self.assertRaises(SystemExit) as caught:
            self.run_main([])
        self.assertEqual(caught.exception.code, 2)

    def test_role_emits_the_matrix_as_json(self) -> None:
        code, out, _ = self.run_main(["--role", "publish", "--file", str(self.decl_path)])
        self.assertEqual(code, 0)
        self.assertEqual(
            json.loads(out),
            [
                {"variant": "base", "image": "dakota", "continue": False},
                {"variant": "nvidia", "image": "true", "continue": True},
            ],
        )

    def test_unknown_role_fails_without_a_traceback(self) -> None:
        code, _, err = self.run_main(["--role", "ghost", "--file", str(self.decl_path)])
        self.assertEqual(code, 1)
        self.assertIn("unknown role 'ghost'", err)

    def test_missing_declaration_fails_closed(self) -> None:
        code, _, err = self.run_main(
            ["--check", "--file", str(self.decl_path.parent / "absent.json")]
        )
        self.assertEqual(code, 1)
        self.assertIn("is missing", err)

    def test_invalid_declaration_fails_before_any_projection(self) -> None:
        self.decl_path.write_text(json.dumps(declaration(variants=[])))
        code, out, err = self.run_main(["--role", "publish", "--file", str(self.decl_path)])
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertIn("non-empty 'variants' list", err)

    def test_check_passes_when_the_workflow_agrees(self) -> None:
        original = image_variants.CONSUMERS
        image_variants.CONSUMERS = {"publish": "publish-image"}
        self.addCleanup(setattr, image_variants, "CONSUMERS", original)
        code, out, err = self.run_main(
            [
                "--check",
                "--file",
                str(self.decl_path),
                "--workflow",
                str(self.workflow_path),
            ]
        )
        self.assertEqual(code, 0, err)
        self.assertIn("2 variants", out)

    def test_check_fails_when_the_workflow_has_drifted(self) -> None:
        original = image_variants.CONSUMERS
        image_variants.CONSUMERS = {"publish": "publish-image"}
        self.addCleanup(setattr, image_variants, "CONSUMERS", original)
        self.workflow_path.write_text(
            WORKFLOW.replace("image: dakota\n", "image: dakota-renamed\n", 1)
        )
        code, _, err = self.run_main(
            [
                "--check",
                "--file",
                str(self.decl_path),
                "--workflow",
                str(self.workflow_path),
            ]
        )
        self.assertEqual(code, 1)
        self.assertIn("has drifted", err)


class RealDeclarationTests(unittest.TestCase):
    """The shipped declaration must satisfy the same rules as the fixtures."""

    def test_every_declared_role_names_a_known_consumer_job(self) -> None:
        decl = image_variants.load(REPOSITORY / ".github/image-variants.json")
        derived = {name for name, spec in decl["roles"].items() if spec["derived"]}
        self.assertEqual(derived, set(image_variants.CONSUMERS))


if __name__ == "__main__":
    unittest.main()
