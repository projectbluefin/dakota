"""Offline release tests: gh is mocked, including through the real Justfile."""

import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch

from scripts import release


ROOT = Path(__file__).resolve().parents[1]
SHA = "a" * 40
OTHER_SHA = "b" * 40


class DispatchTests(unittest.TestCase):
    def invoke(self, *arguments):
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(release.subprocess, "run") as run:
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                try:
                    status = release.main(["dispatch", *arguments])
                except SystemExit as error:
                    status = error.code
        return status, run, stdout.getvalue(), stderr.getvalue()

    def test_default_is_remote_dry_run(self):
        status, run, stdout, _ = self.invoke()
        self.assertEqual(status, 0)
        run.assert_called_once_with([
            "gh", "workflow", "run", "execute-release.yml", "--repo", "projectbluefin/dakota",
            "--ref", "testing", "--raw-field", "dry_run=true",
        ], check=True, shell=False)
        self.assertIn("DRY RUN", stdout)
        self.assertIn("not local uncommitted edits", stdout)
        self.assertIn("does not run the promotion workflow's signature checks", stdout)

    def test_apply_is_explicit(self):
        status, run, stdout, _ = self.invoke("--apply")
        self.assertEqual(status, 0)
        self.assertIn("dry_run=false", run.call_args.args[0])
        self.assertIn("APPLY", stdout)

    def test_full_sha_works_in_either_order_and_normalizes_case(self):
        for args in [("--apply", f"sha={SHA.upper()}"), (f"sha={SHA}", "--apply")]:
            with self.subTest(args=args):
                status, run, stdout, _ = self.invoke(*args)
                self.assertEqual(status, 0)
                self.assertEqual(run.call_args.args[0][-2:], ["--raw-field", f"promote_sha={SHA}"])
                self.assertIn("bypassing", stdout)

    def test_sha_alone_is_still_dry_run(self):
        status, run, _, _ = self.invoke(f"sha={SHA}")
        self.assertEqual(status, 0)
        self.assertIn("dry_run=true", run.call_args.args[0])

    def test_invalid_arguments_never_reach_gh(self):
        cases = [
            ("--apply", "sha="), ("--apply", "sha=787bf4d"),
            ("--apply", "sha=" + "g" * 40), ("sha=" + "a" * 41,),
            ("sha=" + SHA + "\n",), ("sha=" + SHA + " with spaces",),
            ("--apply", f"sha={SHA}", f"sha={SHA}"),
            ("--apply", f"sha={SHA}", "sha="), ("--oops",), ("--app",),
            ("sha=$(echo should-not-run)",), ("sha=`echo should-not-run`",),
            ("sha=" + SHA + "; echo should-not-run",), (SHA,),
        ]
        for args in cases:
            with self.subTest(args=args):
                status, run, stdout, stderr = self.invoke(*args)
                self.assertEqual(status, 2)
                run.assert_not_called()
                self.assertNotIn("Dispatched", stdout)
                self.assertIn("error:", stderr)

    def test_help_never_dispatches(self):
        status, run, stdout, _ = self.invoke("--help")
        self.assertEqual(status, 0)
        run.assert_not_called()
        self.assertIn("--apply", stdout)

    def test_dispatch_failure_is_reported_without_success_message(self):
        for error in [FileNotFoundError("gh unavailable"), subprocess.CalledProcessError(7, ["gh"])]:
            with self.subTest(error=error), patch.object(release.subprocess, "run", side_effect=error):
                stdout, stderr = io.StringIO(), io.StringIO()
                with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                    self.assertEqual(release.main(["dispatch"]), 1)
                self.assertNotIn("Dispatched", stdout.getvalue())
                self.assertIn("ERROR:", stderr.getvalue())


class PublishReadinessTests(unittest.TestCase):
    def check(self, responses, override="", repository="projectbluefin/dakota"):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "output"
            env = {"GITHUB_OUTPUT": str(output), "GITHUB_REPOSITORY": repository, "PROMOTE_SHA": override}
            stdout, stderr = io.StringIO(), io.StringIO()
            with patch.dict(os.environ, env, clear=True):
                with patch.object(release.subprocess, "run", side_effect=responses) as run:
                    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                        status = release.main(["check-publish"])
            return status, run, output.read_text() if output.exists() else "", stdout.getvalue(), stderr.getvalue()

    @staticmethod
    def response(value):
        return subprocess.CompletedProcess(["gh"], 0, stdout=json.dumps(value))

    @staticmethod
    def published(sha=SHA, **updates):
        return dict(databaseId=123, headSha=sha, status="completed", conclusion="success", **updates)

    def test_resolves_testing_and_binds_publish_run(self):
        results = [self.response({"object": {"sha": SHA}}), self.response([self.published()])]
        status, run, output, stdout, _ = self.check(results)
        self.assertEqual(status, 0)
        self.assertEqual(output, f"should-release=true\nbuild_sha={SHA}\npublish_run_id=123\nproceed=true\n")
        self.assertIn("Found successful publish run 123", stdout)
        self.assertEqual(run.call_args_list[0].args[0], [
            "gh", "api", "repos/projectbluefin/dakota/git/ref/heads/testing",
        ])
        self.assertEqual(run.call_args_list[1].args[0], [
            "gh", "run", "list", "--repo", "projectbluefin/dakota", "--workflow", "publish.yml",
            "--branch", "testing", "--commit", SHA, "--status", "success", "--limit", "100",
            "--json", "databaseId,headSha,status,conclusion",
        ])
        for call in run.call_args_list:
            self.assertFalse(call.kwargs["shell"])

    def test_missing_wrong_or_incomplete_publish_fails_without_outputs(self):
        failed = self.published()
        failed["conclusion"] = "failure"
        pending = self.published()
        pending["status"] = "in_progress"
        for runs in [[], [self.published(OTHER_SHA)], [failed], [pending]]:
            with self.subTest(runs=runs):
                status, _, output, _, stderr = self.check([
                    self.response({"object": {"sha": SHA}}), self.response(runs),
                ])
                self.assertEqual(status, 1)
                self.assertEqual(output, "")
                self.assertIn("No successful publish", stderr)

    def test_recovery_full_sha_skips_only_publish_lookup(self):
        status, run, output, stdout, _ = self.check([], SHA.upper())
        self.assertEqual(status, 0)
        run.assert_not_called()
        self.assertEqual(output, f"should-release=true\nbuild_sha={SHA}\npublish_run_id=\nproceed=true\n")
        self.assertIn("Recovery mode", stdout)

    def test_bad_recovery_input_never_calls_gh_or_writes_outputs(self):
        for value in [" ", "787bf4d", "$(echo nope)", SHA + "\nproceed=true", "z" * 40]:
            with self.subTest(value=value):
                status, run, output, _, stderr = self.check([], value)
                self.assertEqual(status, 1)
                run.assert_not_called()
                self.assertEqual(output, "")
                self.assertIn("full 40-character", stderr)

    def test_query_failures_do_not_look_like_no_op_success(self):
        bad_json = subprocess.CompletedProcess(["gh"], 0, stdout="not JSON")
        error = subprocess.CalledProcessError(1, ["gh"], stderr="API unavailable")
        for responses in [[error], [bad_json], [self.response({"object": {"sha": SHA}}), error]]:
            with self.subTest(responses=responses):
                status, _, output, _, stderr = self.check(responses)
                self.assertEqual(status, 1)
                self.assertEqual(output, "")
                self.assertIn("ERROR:", stderr)

    def test_malformed_api_data_fails_closed(self):
        for ref in [{}, {"object": {"sha": "short"}}, None]:
            with self.subTest(ref=ref):
                status, _, output, _, _ = self.check([self.response(ref)])
                self.assertEqual(status, 1)
                self.assertEqual(output, "")
        invalid_id = self.published()
        invalid_id["databaseId"] = "123\nproceed=true"
        for runs in [{}, [None], [invalid_id]]:
            with self.subTest(runs=runs):
                status, _, output, _, _ = self.check([
                    self.response({"object": {"sha": SHA}}), self.response(runs),
                ])
                self.assertEqual(status, 1)
                self.assertEqual(output, "")

    def test_workflow_repository_is_explicit(self):
        status, run, _, _, _ = self.check([
            self.response({"object": {"sha": SHA}}), self.response([self.published()]),
        ], repository="example/dakota")
        self.assertEqual(status, 0)
        self.assertIn("repos/example/dakota/git/ref/heads/testing", run.call_args_list[0].args[0])
        self.assertIn("example/dakota", run.call_args_list[1].args[0])

    def test_missing_output_file_configuration_fails_before_queries(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(release.subprocess, "run") as run:
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(release.main(["check-publish"]), 1)
            run.assert_not_called()


@unittest.skipUnless(shutil.which("just"), "just is required for recipe integration tests")
class RecipeTests(unittest.TestCase):
    def invoke(self, *arguments):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fake_gh = root / "gh"
            fake_gh.write_text(
                f"#!{sys.executable}\nimport json, os, sys\n"
                "from pathlib import Path\n"
                "Path(os.environ['RELEASE_TEST_LOG']).write_text(json.dumps(sys.argv[1:]))\n"
            )
            fake_gh.chmod(0o700)
            log = root / "gh.json"
            marker = root / "must-not-exist"
            args = [arg.replace("MARKER", str(marker)) for arg in arguments]
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"], RELEASE_TEST_LOG=str(log))
            # Starting outside the repo also checks Justfile-relative script resolution.
            result = subprocess.run(
                ["just", "--justfile", str(ROOT / "Justfile"), "release", *args],
                cwd=root, env=env, capture_output=True, text=True, timeout=20,
            )
            return result, json.loads(log.read_text()) if log.exists() else None, marker.exists()

    def test_default_and_apply_reach_only_stub_gh(self):
        for args, field, banner in [((), "dry_run=true", "DRY RUN"), (("--apply",), "dry_run=false", "APPLY")]:
            with self.subTest(args=args):
                result, command, _ = self.invoke(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(field, command)
                self.assertIn("projectbluefin/dakota", command)
                self.assertIn(banner, result.stdout)

    def test_full_sha_is_passed_through(self):
        result, command, _ = self.invoke("--apply", f"sha={SHA}")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"promote_sha={SHA}", command)

    def test_invalid_or_shell_arguments_never_execute_or_dispatch(self):
        for args in [
            ("--apply", "sha="), ("--apply", "sha=787bf4d"), ("--oops",),
            ("sha=$(touch MARKER)",), ("sha=`touch MARKER`",),
            (f"sha={SHA}; touch MARKER",), (f"sha={SHA} with spaces",),
            ("--apply", f"sha={SHA}", f"sha={SHA}"),
        ]:
            with self.subTest(args=args):
                result, command, marker = self.invoke(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(command)
                self.assertFalse(marker)


class WorkflowContractTests(unittest.TestCase):
    def test_workflow_is_manual_with_safe_default_and_python_guard(self):
        workflow = (ROOT / ".github/workflows/execute-release.yml").read_text()
        triggers = workflow.split("\npermissions:", 1)[0]
        self.assertNotIn("\n  schedule:", triggers)
        self.assertIn("\n  workflow_dispatch:", triggers)
        self.assertIn("        type: boolean\n        default: true", triggers)
        self.assertIn("PROMOTE_SHA: ${{ inputs.promote_sha }}", workflow)
        self.assertIn("run: python3 scripts/release.py check-publish", workflow)
        self.assertIn("inputs.dry_run != true", workflow)
        self.assertIn('echo "should-release=false" >> "$GITHUB_OUTPUT"', workflow)
        self.assertIn("nothing to promote", workflow)
        self.assertIn("cosign_identity_regexp:", workflow)

    def test_promotion_does_not_update_or_require_main(self):
        workflow = (ROOT / ".github/workflows/execute-release.yml").read_text()
        self.assertNotIn("update-main-bookmark", workflow)
        self.assertNotIn("git/refs/heads/main", workflow)
        self.assertNotIn("main_sha", workflow)
        self.assertNotIn("main bookmark", workflow)
        execute = workflow.split("\n  execute:\n", 1)[1].split("\n  release-notes:\n", 1)[0]
        self.assertIn("      fast_forward_branch: ''\n", execute)
        self.assertIn("fast_forward_sha: ${{ needs.freshness-check.outputs.build_sha }}", execute)
        self.assertIn("cosign_identity_regexp:", execute)

    def test_post_release_keeps_digest_checks_and_cleanup(self):
        workflow = (ROOT / ".github/workflows/execute-release.yml").read_text()
        post = workflow.split("\n  post-release-verify:\n", 1)[1]
        self.assertIn("needs: [freshness-check, execute, create-multiarch-stable]", post)
        self.assertIn("if: inputs.dry_run != true && needs.execute.result == 'success' && "
                      "needs.create-multiarch-stable.result == 'success'", post)
        self.assertIn("BUILD_SHA: ${{ needs.freshness-check.outputs.build_sha }}", post)
        self.assertEqual(post.split("    steps:\n", 1)[1].splitlines()[0],
                         "      - name: Verify :stable points to promoted digest")
        self.assertIn("Verify :stable-multiarch exists", post)
        self.assertIn('|| { echo "::error::stable-multiarch tag missing"; exit 1; }', post)
        self.assertIn("Detect stale auto/* promotion branches", post)
        for image in ["dakota", "dakota-nvidia", "dakota-gaming", "dakota-nvidia-gaming"]:
            self.assertIn(f"      - name: Prune untagged GHCR versions for {image}\n", post)
            self.assertIn(f"          package-name: {image}\n", post)
        self.assertEqual(post.count("min-versions-to-keep: 100"), 4)
        self.assertEqual(post.count("delete-only-untagged-versions: 'true'"), 4)
        self.assertIn('echo "- promoted testing SHA: $BUILD_SHA"', post)

    def test_tests_are_in_ci_recipe(self):
        justfile = (ROOT / "Justfile").read_text()
        checks = justfile.split("check-publish-workflow:\n", 1)[1].split("\n# Local convenience", 1)[0]
        self.assertIn("just test-release", checks)
        self.assertIn("python3 -m unittest scripts.test_release", justfile)


@unittest.skipUnless(shutil.which("bash"), "bash is required to exercise the workflow step")
class PostReleaseDigestTests(unittest.TestCase):
    IMAGES = ("dakota", "dakota-nvidia", "dakota-gaming", "dakota-nvidia-gaming")

    def verify(self, mismatch=""):
        # Exercise the actual workflow step, not a reimplementation. All external
        # commands are stubbed: no package installation, registry access or writes.
        workflow = (ROOT / ".github/workflows/execute-release.yml").read_text()
        step = workflow.split("      - name: Verify :stable points to promoted digest\n", 1)[1]
        script = textwrap.dedent(step.split("      - name:", 1)[0].split("        run: |\n", 1)[1])
        stub = f"#!{sys.executable}\n" + textwrap.dedent('''\
            import json, os, sys
            from pathlib import Path
            tool, args = Path(sys.argv[0]).name, sys.argv[1:]
            with Path(os.environ["RELEASE_TEST_LOG"]).open("a") as log:
                log.write(json.dumps([tool, *args]) + "\\n")
            if tool == "sudo":
                assert args in (["apt-get", "update", "-qq"],
                                ["apt-get", "install", "-y", "-qq", "skopeo"])
            elif tool == "skopeo":
                assert args[:2] == ["inspect", "--no-tags"] and len(args) == 3
                image, tag = args[2].removeprefix("docker://ghcr.io/projectbluefin/").split(":")
                assert tag in (os.environ["BUILD_SHA"], "stable")
                mismatch = tag == "stable" and image == os.environ["MISMATCH_IMAGE"]
                print(json.dumps({"Digest": "sha256:" + ("b" if mismatch else "a") * 64}))
            elif tool == "jq":
                assert args == ["-r", ".Digest"]
                print(json.load(sys.stdin)["Digest"])
            else:
                sys.exit(99)
            ''')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "commands.jsonl"
            for name in ["sudo", "skopeo", "jq"]:
                executable = root / name
                executable.write_text(stub)
                executable.chmod(0o700)
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"],
                       RELEASE_TEST_LOG=str(log), BUILD_SHA=SHA, MISMATCH_IMAGE=mismatch)
            result = subprocess.run(["bash", "-c", script], cwd=root, env=env,
                                    capture_output=True, text=True, timeout=20)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
        return result, calls

    def test_all_four_matching_digests_pass_without_main_lookup(self):
        result, calls = self.verify()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        refs = [call[-1] for call in calls if call[0] == "skopeo"]
        self.assertEqual(refs, [f"docker://ghcr.io/projectbluefin/{image}:{tag}"
                                for image in self.IMAGES for tag in [SHA, "stable"]])
        self.assertEqual(result.stdout.count("digest verified:"), 4)

    def test_each_variant_digest_mismatch_still_fails(self):
        for image in self.IMAGES:
            with self.subTest(image=image):
                result, _ = self.verify(image)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(f"::error::{image}:stable digest=", result.stdout)


if __name__ == "__main__":
    unittest.main()
