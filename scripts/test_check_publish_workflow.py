#!/usr/bin/env python3
import copy
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[1]
CHECKER = REPOSITORY / "scripts" / "check_publish_workflow.py"


class CheckPublishWorkflowTests(unittest.TestCase):
    def run_checker(self, workspace: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, CHECKER],
            cwd=workspace,
            text=True,
            capture_output=True,
            check=False,
        )

    def copy_workspace(self, workspace: Path) -> None:
        shutil.copytree(REPOSITORY / ".github", workspace / ".github")

    def mutate(self, relative_path: str, old: str, new: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as tempdir:
            workspace = Path(tempdir)
            self.copy_workspace(workspace)
            path = workspace / relative_path
            original = path.read_text()
            self.assertIn(old, original)
            path.write_text(original.replace(old, new, 1))
            return self.run_checker(workspace)

    def test_current_configuration_passes(self) -> None:
        result = self.run_checker(REPOSITORY)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_unterminated_composite_action_shell(self) -> None:
        result = self.mutate(
            ".github/actions/generate-bst-ci-config/action.yml",
            "        set -euo pipefail\n",
            "        if true; then\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_missing_remote_execution_block(self) -> None:
        result = self.mutate(
            ".github/actions/generate-bst-ci-config/action.yml",
            "        remote-execution:\n",
            "        disabled-executor:\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_serial_build_matrix(self) -> None:
        result = self.mutate(
            ".github/workflows/build.yml",
            "      max-parallel: 4\n",
            "      max-parallel: 1\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_explicit_artifact_pull(self) -> None:
        result = self.mutate(
            ".github/workflows/build.yml",
            "      - name: Count elements for progress tracking\n",
            "      - name: Pull prebuilt artifacts from remote CAS\n"
            "        run: true\n\n"
            "      - name: Count elements for progress tracking\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_remote_publish_export(self) -> None:
        result = self.mutate(
            ".github/workflows/publish.yml",
            "          enable-remote-execution: 'false'\n",
            "          enable-remote-execution: 'true'\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_inline_variant_matrix_drift(self) -> None:
        result = self.mutate(
            ".github/workflows/publish.yml",
            "          - variant: nvidia-gaming\n            image_suffix: '-nvidia-gaming'\n            continue: true\n",
            "",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("drifted", result.stderr)

    def test_rejects_declaration_drift_from_workflow(self) -> None:
        result = self.mutate(
            ".github/image-variants.json",
            '"image_suffix": "-nvidia-gaming"',
            '"image_suffix": "-nvidia-game"',
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("drifted", result.stderr)

    def test_rejects_variant_missing_a_role_membership(self) -> None:
        result = self.mutate(
            ".github/image-variants.json",
            '        "scan": {},\n        "rollback": {}',
            '        "scan": {}',
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("does not declare membership", result.stderr)

    def test_rejects_duplicate_variant_image(self) -> None:
        result = self.mutate(
            ".github/image-variants.json",
            '"image": "dakota-gaming"',
            '"image": "dakota-nvidia"',
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_exclusion_without_a_reason(self) -> None:
        result = self.mutate(
            ".github/image-variants.json",
            '"excluded": "no SBOM entry wired for gaming builds yet"',
            '"excluded": ""',
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_malformed_declaration(self) -> None:
        result = self.mutate(
            ".github/image-variants.json", '"variants": [', '"variants": [ ,'
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("not valid JSON", result.stderr)

    def test_rejects_default_sbom_variant_becoming_fail_closed(self) -> None:
        result = self.mutate(
            ".github/image-variants.json",
            '"sbom": { "continue": true },\n        "tag_testing": { "continue": false }',
            '"sbom": { "continue": false },\n        "tag_testing": { "continue": false }',
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)


class ImageVariantsMatrixTests(unittest.TestCase):
    """The derived matrices must equal what publish.yml used to state inline."""

    def setUp(self) -> None:
        sys.path.insert(0, str(REPOSITORY / ".github/scripts"))
        import image_variants

        self.image_variants = image_variants
        self.declaration = image_variants.load(REPOSITORY / ".github/image-variants.json")

    def test_declaration_is_valid(self) -> None:
        self.assertEqual(self.image_variants.validate(self.declaration), [])

    def test_publish_matrix_covers_all_four_variants(self) -> None:
        matrix = self.image_variants.matrix_for(self.declaration, "publish")
        self.assertEqual(
            [entry["variant"] for entry in matrix],
            ["default", "nvidia", "gaming", "nvidia-gaming"],
        )

    def test_sbom_matrix_excludes_gaming_variants(self) -> None:
        matrix = self.image_variants.matrix_for(self.declaration, "sbom")
        self.assertEqual([entry["variant"] for entry in matrix], ["default", "nvidia"])

    def test_gaming_variants_carry_the_build_gaming_flag(self) -> None:
        matrix = {
            entry["variant"]: entry
            for entry in self.image_variants.matrix_for(self.declaration, "publish")
        }
        self.assertEqual(matrix["gaming"]["gaming"], "true")
        self.assertEqual(matrix["gaming"]["export_variant"], "default")
        self.assertEqual(matrix["nvidia-gaming"]["export_variant"], "nvidia")
        self.assertNotIn("gaming", matrix["default"])

    def test_role_projection_omits_undeclared_fields(self) -> None:
        matrix = self.image_variants.matrix_for(self.declaration, "tag_testing")
        for entry in matrix:
            self.assertEqual(set(entry), {"variant", "image_suffix", "continue"})

    def test_parser_preserves_scalar_types(self) -> None:
        workflow = (REPOSITORY / ".github/workflows/publish.yml").read_text()
        matrix = {
            entry["variant"]: entry
            for entry in self.image_variants.parse_workflow_matrix(
                workflow, "publish-image"
            )
        }
        # Quoting is significant: `gaming: 'true'` is the string consumed by
        # BUILD_GAMING, while `continue: false` is a real boolean.
        self.assertEqual(matrix["gaming"]["gaming"], "true")
        self.assertIs(matrix["default"]["continue"], False)
        self.assertIs(matrix["nvidia"]["continue"], True)
        self.assertEqual(matrix["default"]["image_suffix"], "")

    def test_every_workflow_matrix_matches_the_declaration(self) -> None:
        workflow = (REPOSITORY / ".github/workflows/publish.yml").read_text()
        self.assertEqual(
            self.image_variants.check_workflow_drift(
                self.declaration, workflow, self.image_variants.CONSUMERS
            ),
            [],
        )


class ConsumerMembershipTests(unittest.TestCase):
    """Non-derived consumers must name exactly their declared variants (#1434)."""

    def setUp(self) -> None:
        sys.path.insert(0, str(REPOSITORY / ".github/scripts"))
        import image_variants

        self.image_variants = image_variants
        self.declaration = image_variants.load(REPOSITORY / ".github/image-variants.json")

    def read_repository(self, path: str) -> str:
        return (REPOSITORY / path).read_text()

    def declaration_copy(self) -> dict:
        return copy.deepcopy(self.declaration)

    def test_repository_consumers_agree_with_the_declaration(self) -> None:
        self.assertEqual(
            self.image_variants.check_consumer_membership(
                self.declaration, self.read_repository
            ),
            [],
        )

    def test_every_non_derived_role_is_actually_checked(self) -> None:
        # A role silently skipped by the gate is the failure mode this whole
        # check exists to prevent, so assert the set it walks.
        checked = {
            role
            for role, spec in self.declaration["roles"].items()
            if not spec.get("derived")
        }
        self.assertEqual(
            checked, {"promote_stable", "smoke", "scan", "rollback"}
        )

    def test_consumer_dropping_a_declared_image_fails(self) -> None:
        def read(path: str) -> str:
            text = self.read_repository(path)
            if path.endswith("publish-smoke.yml"):
                text = text.replace("dakota-nvidia", "dakota-removed")
            return text

        errors = self.image_variants.check_consumer_membership(
            self.declaration, read
        )
        self.assertTrue(
            any("includes image 'dakota-nvidia'" in e for e in errors), errors
        )

    def test_consumer_gaining_an_excluded_image_fails(self) -> None:
        def read(path: str) -> str:
            text = self.read_repository(path)
            if path.endswith("vulnerability-scan.yml"):
                text = text.replace(
                    '{"image_name":"dakota-nvidia"}',
                    '{"image_name":"dakota-nvidia"},{"image_name":"dakota-gaming"}',
                )
            return text

        errors = self.image_variants.check_consumer_membership(
            self.declaration, read
        )
        self.assertTrue(
            any("excludes image 'dakota-gaming'" in e for e in errors), errors
        )

    def test_unreadable_consumer_fails_closed(self) -> None:
        def read(path: str) -> str:
            if path.endswith("rollback-stable.yml"):
                raise FileNotFoundError(path)
            return self.read_repository(path)

        errors = self.image_variants.check_consumer_membership(
            self.declaration, read
        )
        self.assertTrue(any("cannot be read" in e for e in errors), errors)

    def test_derived_roles_are_not_membership_checked(self) -> None:
        # publish.yml is gated field by field by check_workflow_drift; the
        # name gate must not double-report it.
        declaration = self.declaration_copy()
        errors = self.image_variants.check_consumer_membership(
            declaration, lambda path: ""
        )
        self.assertTrue(errors)
        self.assertFalse(
            [e for e in errors if "publish.yml" in e],
            "derived roles must be left to the matrix drift gate",
        )

    def test_image_names_are_matched_as_whole_tokens(self) -> None:
        mentions = self.image_variants.mentions_image
        self.assertFalse(mentions("ghcr.io/projectbluefin/dakota-nvidia", "dakota"))
        self.assertFalse(mentions("sbom-dakota", "dakota"))
        self.assertFalse(mentions("group: dakota-execute-release", "dakota"))
        self.assertFalse(mentions("dakota-nvidia-gaming", "dakota-nvidia"))
        self.assertTrue(mentions("ghcr.io/projectbluefin/dakota:stable", "dakota"))
        self.assertTrue(mentions('{"image":"dakota"}', "dakota"))
        self.assertTrue(mentions("artifact dakota.spdx.json", "dakota"))

    def test_consumer_path_drops_the_job_qualifier(self) -> None:
        self.assertEqual(
            self.image_variants.consumer_path(
                {"consumer": ".github/workflows/publish.yml (publish-image)"}
            ),
            ".github/workflows/publish.yml",
        )
        self.assertEqual(
            self.image_variants.consumer_path(
                {"consumer": ".github/workflows/rollback-stable.yml"}
            ),
            ".github/workflows/rollback-stable.yml",
        )


if __name__ == "__main__":
    unittest.main()
