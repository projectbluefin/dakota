"""Offline regression tests for recipe identity, runner wiring and cleanup."""
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from scripts import ownership_metadata as metadata
from scripts.test_ownership_cold_cache import cleanup_resources

REPO = Path(__file__).resolve().parents[1]
IMAGE_ID = "a" * 64


class ColdCleanupTests(unittest.TestCase):
    def test_diagnostic_failures_do_not_prevent_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "receiver.cid").write_text("b" * 64)
            # Exercise fingerprint read failure and evidence write failure.
            for refs in (["missing/ref"], []):
                with self.subTest(refs=refs):
                    with mock.patch("scripts.test_ownership_cold_cache.subprocess.run") as run:
                        errors = cleanup_resources(root, [IMAGE_ID], root / "absent", root, refs, {})
                    self.assertTrue(any("fingerprints" in error for error in errors))
                    self.assertEqual(sum("container log" in error for error in errors), 2)
                    commands = [call.args[0] for call in run.call_args_list]
                    for cid in (IMAGE_ID, "b" * 64):
                        self.assertIn(["podman", "rm", "-f", "--ignore", cid], commands)
                    self.assertIn(["podman", "unshare", "rm", "-rf", "--", str(root)], commands)

    def test_failed_container_removal_preserves_storage_but_attempts_others(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def run(command, **kwargs):
                if command[:3] == ["podman", "rm", "-f"] and command[-1] == IMAGE_ID:
                    raise subprocess.CalledProcessError(1, command)

            with mock.patch("scripts.test_ownership_cold_cache.subprocess.run", side_effect=run) as calls:
                errors = cleanup_resources(root, [IMAGE_ID, "b" * 64], root, root, [], {})
            commands = [call.args[0] for call in calls.call_args_list]
            self.assertIn(["podman", "rm", "-f", "--ignore", "b" * 64], commands)
            self.assertFalse(any(command[:2] == ["podman", "unshare"] for command in commands))
            self.assertTrue(any("preserving temporary directory" in error for error in errors))


@unittest.skipUnless(shutil.which("just"), "requires just")
class RecipeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        shutil.copy2(REPO / "Justfile", self.root / "Justfile")
        (self.root / "scripts").mkdir()
        shutil.copy2(REPO / "scripts/ownership_metadata.py", self.root / "scripts")
        (self.root / "files/fakecap").mkdir(parents=True)
        helper = self.root / "files/fakecap/fakecap-restore"
        helper.write_text("#!/bin/sh\nexit 9\n")
        helper.chmod(0o755)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        stub = self.bin / "stub"
        stub.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
root = pathlib.Path(os.environ["FIXTURE_ROOT"])
name, args = pathlib.Path(sys.argv[0]).name, sys.argv[1:]
with (root / "calls").open("a") as out:
    out.write(json.dumps([name, *args]) + "\\n")
if name == "id":
    print(os.environ.get("FAKE_UID", "0"))
elif name == "sudo":
    os.execvp(args[0], args)
elif name == "podman":
    if args[:2] == ["image", "inspect"]:
        print("a" * 64)
    elif args[0] == "inspect":
        print("[]")
    elif args[:2] == ["image", "mount"]:
        print(root / "lower")
    elif args[0] == "run":
        if os.environ.get("FAIL_CHUNKAH") == "1":
            sys.exit(23)
        assert args[args.index("--output") + 1] == "oci:/chunkah-output/image"
        output = next(value.split(":")[0] for value in args if value.endswith(":/chunkah-output:rw"))
        (pathlib.Path(output) / "image").mkdir()
    elif args[:2] == ["pull", "--quiet"]:
        if os.environ.get("FAIL_IMPORT") == "1":
            sys.exit(24)
        assert args[2].startswith("oci:") and pathlib.Path(args[2][4:]).is_dir()
        print("invalid" if os.environ.get("BAD_IMAGE_ID") == "1" else "sha256:" + "b" * 64)
    elif args[0] == "save":
        print("fixture archive")
    elif args[0] == "load":
        assert sys.stdin.read() == "fixture archive\\n"
elif name == "mktemp":
    countfile = root / "count"
    count = int(countfile.read_text()) + 1 if countfile.exists() else 1
    countfile.write_text(str(count))
    if count == int(os.environ.get("FAIL_MKTEMP", "0")):
        sys.exit(7)
    directory = root / f"allocated-{count}"
    directory.mkdir()
    print(directory)
elif name == "mountpoint":
    sys.exit(0 if os.environ.get("BUSY_OVERLAY") == "1" else 1)
elif name == "umount":
    sys.exit(5)
''')
        stub.chmod(0o755)
        for name in ("id", "sudo", "podman", "mktemp", "mount", "mountpoint", "umount", "bst-runner"):
            (self.bin / name).symlink_to(stub)
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}", FIXTURE_ROOT=str(self.root))
        for name in ("BST_RUNNER", "BUILD_SKIP_CHUNKIFY", "BUILD_CHUNKIFY_COPY_TO_USER"):
            self.env.pop(name, None)
        folder = self.root / ".build-ownership" / IMAGE_ID
        folder.mkdir(parents=True)
        (folder / "image-id").write_text(IMAGE_ID)
        image = self.root / "image"
        image.mkdir()
        (image / "tool").write_text("fixture\n")
        tree = metadata.snapshot(image)
        payload = metadata._final_payload(tree, {"tool": {"component": "fixture", "interval": "weekly",
                                            "producer": "fixture"}}, "fixture/key", "0" * 64,
                                          "amd64", "default", "sha256:" + "0" * 64)
        payload.update(binding="final-image", image_id=IMAGE_ID)
        self.manifest = folder / "fakecap-manifest.tsv"
        sidecar = folder / "ownership-final.json"
        metadata._write_json(sidecar, payload)
        metadata.validate_exported(image, sidecar, None, None, self.manifest)

    def run_recipe(self, *args, **environment):
        return subprocess.run(["just", *args], cwd=self.root, env=dict(self.env, **environment),
                              text=True, capture_output=True)

    def calls(self):
        return [json.loads(line) for line in (self.root / "calls").read_text().splitlines()]

    def test_runner_receives_arguments_without_wrapper_rewriting(self):
        result = self.run_recipe("bst", "artifact", "checkout", "oci/bluefin.bst", "--directory", "/src/.build-out",
                                 BST_RUNNER=str(self.bin / "bst-runner"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [["bst-runner", "artifact", "checkout", "oci/bluefin.bst",
                                        "--directory", "/src/.build-out"]])

    def test_partial_allocation_failure_cleans_every_acquired_resource(self):
        for failure in range(1, 6):
            with self.subTest(allocation=failure):
                for name in ("count", "calls"):
                    (self.root / name).unlink(missing_ok=True)
                result = self.run_recipe("chunkify", "localhost/fixture:latest", FAIL_MKTEMP=str(failure))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("exit code 7", result.stderr)
                self.assertNotIn("unbound variable", result.stderr)
                self.assertFalse(list(self.root.glob("allocated-*")))
                calls = self.calls()
                self.assertIn(["podman", "inspect", IMAGE_ID], calls)
                if failure > 1:
                    self.assertIn(["podman", "image", "mount", IMAGE_ID], calls)
                    self.assertIn(["podman", "image", "umount", IMAGE_ID], calls)
                self.assertEqual(sum("localhost/fixture:latest" in call for call in calls), 1)

    def test_corrupt_manifest_rejected_before_mount(self):
        self.manifest.write_bytes(b"")
        result = self.run_recipe("chunkify", "localhost/fixture:latest")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("TSV does not match", result.stderr)
        self.assertFalse(any(call[:3] == ["podman", "image", "mount"] for call in self.calls()))
        self.assertFalse(list(self.root.glob("allocated-*")))

    def test_directory_output_uses_one_store_by_default(self):
        (self.root / "files/fakecap/fakecap-restore").write_text("#!/bin/sh\nexit 0\n")
        result = self.run_recipe("chunkify", "localhost/fixture:latest", FAKE_UID="1000")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        build = next(call for call in calls if call[:2] == ["podman", "run"])
        self.assertEqual(build[build.index("--output") + 1], "oci:/chunkah-output/image")
        self.assertNotIn("--compressed", build)
        self.assertEqual(build[build.index("--max-layers") + 1], "120")
        self.assertTrue(any("v0.6.0@sha256:" in value for value in build))
        self.assertIn(["sudo", "podman", "tag", "b" * 64, "localhost/fixture:latest"], calls)
        self.assertFalse(any(call[:2] in (["podman", "save"], ["podman", "load"]) for call in calls))
        allocations = [call for call in calls if call[0] == "mktemp"]
        self.assertIn("-p", allocations[-1])  # large OCI output never uses default /tmp
        self.assertFalse(list(self.root.glob("allocated-*")))

    def test_rootless_copy_is_explicit_and_uses_the_imported_id(self):
        (self.root / "files/fakecap/fakecap-restore").write_text("#!/bin/sh\nexit 0\n")
        result = self.run_recipe("chunkify", "localhost/fixture:latest", FAKE_UID="1000",
                                 BUILD_CHUNKIFY_COPY_TO_USER="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertIn(["sudo", "podman", "save", "b" * 64], calls)
        self.assertIn(["podman", "load"], calls)
        self.assertEqual(calls.count(["podman", "tag", "b" * 64, "localhost/fixture:latest"]), 2)
        self.assertFalse(list(self.root.glob("allocated-*")))

    def test_failed_output_or_import_never_retags_and_cleans_scratch(self):
        (self.root / "files/fakecap/fakecap-restore").write_text("#!/bin/sh\nexit 0\n")
        for setting in ("FAIL_CHUNKAH", "FAIL_IMPORT", "BAD_IMAGE_ID"):
            with self.subTest(setting=setting):
                for name in ("count", "calls"):
                    (self.root / name).unlink(missing_ok=True)
                result = self.run_recipe("chunkify", "localhost/fixture:latest", **{setting: "1"})
                self.assertNotEqual(result.returncode, 0)
                if setting == "BAD_IMAGE_ID":
                    self.assertIn("invalid imported Chunkah image ID", result.stderr)
                calls = self.calls()
                self.assertFalse(any(call[:2] == ["podman", "tag"] for call in calls))
                self.assertIn(["podman", "image", "umount", IMAGE_ID], calls)
                self.assertFalse(list(self.root.glob("allocated-*")))

    def test_busy_overlay_is_preserved_without_masking_original_failure(self):
        result = self.run_recipe("chunkify", "localhost/fixture:latest", BUSY_OVERLAY="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exit code 9", result.stderr)
        self.assertIn("preserving overlay", result.stderr)
        self.assertFalse((self.root / "allocated-1").exists())  # private manifest is still cleaned
        self.assertEqual(len(list(self.root.glob("allocated-*"))), 3)
        self.assertNotIn(["podman", "image", "umount", IMAGE_ID], self.calls())


if __name__ == "__main__":
    unittest.main()
