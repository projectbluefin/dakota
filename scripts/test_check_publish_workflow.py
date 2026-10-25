#!/usr/bin/env python3
import ast
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[1]
CHECKER = REPOSITORY / "scripts" / "check_publish_workflow.py"


class CheckPublishWorkflowTests(unittest.TestCase):
    def test_checker_has_no_shadowed_functions(self) -> None:
        functions = [node.name for node in ast.parse(CHECKER.read_text()).body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))]
        self.assertEqual(len(functions), len(set(functions)))

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

    def test_rejects_socket_without_push_guard(self) -> None:
        result = self.mutate(
            ".github/actions/generate-bst-ci-config/action.yml",
            '           [[ "${ENABLE_PUSH:-true}" == "true" ]] &&\n',
            "",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("must ignore the casd socket", result.stderr)

    def test_rejects_socket_config_with_mtls_endpoint(self) -> None:
        result = self.mutate(
            ".github/actions/generate-bst-ci-config/action.yml",
            '          CAS_URL="unix:${CASD_SOCKET}"\n',
            '          CAS_URL="https://cache.projectbluefin.io:11002"\n',
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("through the socket", result.stderr)

    def test_rejects_serial_build_matrix(self) -> None:
        result = self.mutate(
            ".github/workflows/build.yml",
            "      max-parallel: 2\n",
            "      max-parallel: 1\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_optional_default_image(self) -> None:
        result = self.mutate(
            ".github/workflows/build.yml",
            "            required: oci/bluefin.bst\n",
            "            required: \"\"\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_signing_job_on_build_pool(self) -> None:
        sign = "runs-on: ${{ vars.DAKOTA_SIGN_RUNNER || 'ubuntu-26.04' }}"
        cas = "runs-on: ${{ vars.DAKOTA_BUILD_RUNNER || 'ubuntu-26.04' }}"
        for workflow in (".github/workflows/build.yml", ".github/workflows/publish.yml"):
            with self.subTest(workflow=workflow):
                text = (REPOSITORY / workflow).read_text()
                self.assertEqual(text.count(sign), 1)
                result = self.mutate(workflow, sign, cas)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("signing pool", result.stderr)

    def test_rejects_signing_pool_outside_signing_jobs(self) -> None:
        result = self.mutate(
            ".github/workflows/build.yml",
            "    runs-on: ${{ vars.DAKOTA_BUILD_RUNNER || 'ubuntu-26.04' }}",
            "    runs-on: ${{ vars.DAKOTA_SIGN_RUNNER || 'ubuntu-26.04' }}",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("outside a signing job", result.stderr)

    def test_rejects_conditional_key_removal(self) -> None:
        result = self.mutate(
            ".github/workflows/publish.yml",
            "        if: always()\n        run: rm -f files/boot-keys/private/secure-boot.key",
            "        run: rm -f files/boot-keys/private/secure-boot.key",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("if: always()", result.stderr)

    def test_rejects_grouped_matrix_drift(self) -> None:
        result = self.mutate(
            ".github/workflows/publish.yml",
            "            base_continue: false\n",
            "            base_continue: true\n",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("drifted", result.stderr)

    def test_rejects_unwired_optional_image_flag(self) -> None:
        result = self.mutate(
            ".github/workflows/publish.yml",
            "        continue-on-error: ${{ matrix.nvidia_continue }}\n",
            "",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("must wire", result.stderr)

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

    def test_rejects_signing_with_cas_pushes(self) -> None:
        build = (REPOSITORY / ".github/workflows/build.yml").read_text()
        pr_image = build[build.index("  pr-image:"):]
        self.assertIn("enable-push: 'false'", pr_image)
        result = self.mutate(
            ".github/workflows/build.yml",
            pr_image,
            pr_image.replace("enable-push: 'false'", "enable-push: 'true'", 1),
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_signing_key_in_build_job(self) -> None:
        result = self.mutate(
            ".github/workflows/build.yml",
            "      max-parallel: 2\n",
            "      max-parallel: 2\n"
            "    env:\n"
            "      DAKOTA_SECURE_BOOT_KEY: ${{ secrets.DAKOTA_SECURE_BOOT_KEY }}\n",
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
        self.assertEqual([entry["group"] for entry in matrix], ["standard", "gaming"])
        self.assertEqual(
            [(entry["base_variant"], entry["nvidia_variant"]) for entry in matrix],
            [("default", "nvidia"), ("gaming", "nvidia-gaming")],
        )

    def test_sbom_matrix_excludes_gaming_variants(self) -> None:
        matrix = self.image_variants.matrix_for(self.declaration, "sbom")
        self.assertEqual([entry["variant"] for entry in matrix], ["default", "nvidia"])

    def test_gaming_variants_carry_the_build_gaming_flag(self) -> None:
        standard, gaming = self.image_variants.matrix_for(self.declaration, "publish")
        self.assertEqual(standard["gaming"], "false")
        self.assertEqual(gaming["gaming"], "true")
        self.assertEqual(gaming["base_image_suffix"], "-gaming")
        self.assertEqual(gaming["nvidia_image_suffix"], "-nvidia-gaming")

    def test_only_the_default_image_is_required(self) -> None:
        standard, gaming = self.image_variants.matrix_for(self.declaration, "publish")
        self.assertIs(standard["continue"], False)
        self.assertIs(standard["base_continue"], False)
        self.assertIs(standard["nvidia_continue"], True)
        self.assertIs(gaming["continue"], True)

    def test_role_projection_omits_undeclared_fields(self) -> None:
        matrix = self.image_variants.matrix_for(self.declaration, "tag_testing")
        for entry in matrix:
            self.assertEqual(set(entry), {"variant", "image_suffix", "continue"})

    def test_parser_preserves_scalar_types(self) -> None:
        workflow = (REPOSITORY / ".github/workflows/publish.yml").read_text()
        matrix = {
            entry["group"]: entry
            for entry in self.image_variants.parse_workflow_matrix(
                workflow, "publish-image"
            )
        }
        # Quoting is significant: `gaming: 'true'` is the string consumed by
        # BUILD_GAMING, while `continue: false` is a real boolean.
        self.assertEqual(matrix["gaming"]["gaming"], "true")
        self.assertIs(matrix["standard"]["continue"], False)
        self.assertIs(matrix["standard"]["nvidia_continue"], True)
        self.assertEqual(matrix["standard"]["base_image_suffix"], "")

    def test_every_workflow_matrix_matches_the_declaration(self) -> None:
        workflow = (REPOSITORY / ".github/workflows/publish.yml").read_text()
        self.assertEqual(
            self.image_variants.check_workflow_drift(
                self.declaration, workflow, self.image_variants.CONSUMERS
            ),
            [],
        )


if __name__ == "__main__":
    unittest.main()
