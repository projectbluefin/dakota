#!/usr/bin/env python3
"""Tests for the decisions in scripts/pr_test.py and scripts/live_iso.py.

Nothing here touches a registry, a bucket, a VM or BuildStream.
"""
from __future__ import annotations

import hashlib
import io
import os
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

from scripts import live_iso, pr_test

DIGEST = "sha256:" + "a" * 64
IMAGE = "ghcr.io/projectbluefin/dakota"


class IsoChanged(unittest.TestCase):
    def test_iso_sources_count(self) -> None:
        for path in ("elements/iso/live.bst", "files/live-iso/build.py", "patches/btrfs-progs/0001-x.patch",
                     "scripts/iso_smoke_boot.py", "scripts/live_iso.py", "scripts/pr_test.py"):
            self.assertTrue(pr_test.iso_changed(["README.md", path]), path)

    def test_other_changes_do_not(self) -> None:
        self.assertFalse(pr_test.iso_changed(["elements/oci/bluefin.bst", "docs/live-iso.md",
                                              "scripts/iso_smoke_boot.py.orig", "x/elements/iso/a", ""]))


class Names(unittest.TestCase):
    def test_iso_is_named_after_image_and_tag(self) -> None:
        self.assertEqual(pr_test.iso_name(IMAGE, "pr-12"), "dakota-pr-12.iso")
        self.assertEqual(pr_test.iso_name("dakota-nvidia", "pr-12"), "dakota-nvidia-pr-12.iso")

    def test_cleanup_names_only_this_pull_requests_objects(self) -> None:
        self.assertEqual(pr_test.iso_objects(["dakota", "dakota-nvidia"], "pr-7"), [
            "dakota-pr-7.iso", "dakota-pr-7.iso-CHECKSUM",
            "dakota-nvidia-pr-7.iso", "dakota-nvidia-pr-7.iso-CHECKSUM"])


class ImageProblem(unittest.TestCase):
    def test_matching_revision_is_accepted(self) -> None:
        inspect = {"Digest": DIGEST, "Labels": {pr_test.REVISION_LABEL: "abc"}}
        self.assertEqual(pr_test.image_problem(inspect, "abc"), "")

    def test_image_without_the_label_is_refused(self) -> None:
        self.assertIn("unknown commit", pr_test.image_problem({"Digest": DIGEST, "Labels": None}, "abc"))

    def test_other_revision_is_refused(self) -> None:
        inspect = {"Digest": DIGEST, "Labels": {pr_test.REVISION_LABEL: "old"}}
        self.assertIn("built from old", pr_test.image_problem(inspect, "abc"))

    def test_missing_digest_is_refused(self) -> None:
        self.assertIn("digest", pr_test.image_problem({"Digest": "latest"}, "abc"))


class MetadataProblem(unittest.TestCase):
    good = {"manifest_digest": DIGEST, "image_reference": f"{IMAGE}:pr-1", "esp_mb": 256}

    def test_matching_metadata_is_accepted(self) -> None:
        self.assertEqual(pr_test.metadata_problem(self.good, DIGEST, f"{IMAGE}:pr-1"), "")

    def test_each_mismatch_is_named(self) -> None:
        self.assertIn("carries", pr_test.metadata_problem({**self.good, "manifest_digest": "sha256:b"}, DIGEST, f"{IMAGE}:pr-1"))
        self.assertIn("updates from", pr_test.metadata_problem(self.good, DIGEST, f"{IMAGE}:testing"))
        self.assertIn("ESP", pr_test.metadata_problem({**self.good, "esp_mb": 264}, DIGEST, f"{IMAGE}:pr-1"))
        self.assertIn("ESP", pr_test.metadata_problem({**self.good, "esp_mb": None}, DIGEST, f"{IMAGE}:pr-1"))


class Upload(unittest.TestCase):
    def test_checksum_line_is_what_sha256sum_writes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "dakota-pr-1.iso"
            path.write_bytes(b"iso")
            self.assertEqual(pr_test.checksum_line(path), f"{hashlib.sha256(b'iso').hexdigest()}  dakota-pr-1.iso\n")

    def test_rclone_needs_all_three_credentials(self) -> None:
        full = {"R2_ACCESS_KEY": "k", "R2_SECRET_KEY": "s", "R2_ENDPOINT": "https://e"}
        self.assertEqual(pr_test.rclone_environment(full)["RCLONE_CONFIG_R2_ACCESS_KEY_ID"], "k")
        for missing in full:
            self.assertIsNone(pr_test.rclone_environment({**full, missing: ""}))

    def test_upload_without_credentials_fails_the_step(self) -> None:
        with mock.patch.dict(os.environ, {"R2_ACCESS_KEY": ""}), redirect_stdout(io.StringIO()) as out:
            self.assertEqual(pr_test.main(["upload-iso", "--iso", "/nonexistent.iso"]), 1)
        self.assertIn("::error::R2 credentials are not configured", out.getvalue())


class LiveIso(unittest.TestCase):
    def test_origin_has_to_be_a_tagged_reference(self) -> None:
        self.assertEqual(live_iso.origin_problem("ghcr.io/projectbluefin/dakota:pr-12"), "")
        for bad in ("", "dakota", "ghcr.io/projectbluefin/dakota", "docker://ghcr.io/a/b:c", "ghcr.io/a/b@sha256:1"):
            self.assertTrue(live_iso.origin_problem(bad), bad)

    def test_sandbox_only_writes_to_mounts(self) -> None:
        command = live_iso.sandbox_command("ghcr.io/projectbluefin/dakota:pr-12")
        mounts = [command[i + 1:i + 3] for i, word in enumerate(command) if word == "--mount"]
        self.assertEqual(mounts, [["/src/.build-iso/image", "/image"], ["/src/.build-iso/work", "/build"],
                                  ["/src/.build-iso/out", "/out"]])
        self.assertEqual(command[-3:], ["/image", "/out", "ghcr.io/projectbluefin/dakota:pr-12"])
        self.assertIn("SOURCE_DATE_EPOCH=1321009871", command)

    def test_bad_origin_stops_before_anything_is_removed(self) -> None:
        with mock.patch.object(live_iso.shutil, "rmtree") as rmtree, mock.patch.object(live_iso.subprocess, "run") as run:
            self.assertEqual(live_iso.main(["docker://x", "not-a-reference"]), 1)
        rmtree.assert_not_called()
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
