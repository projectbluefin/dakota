#!/usr/bin/env python3
"""Real Chunkah ownership BuildStream fixture (never part of offline unit CI)."""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMAGE = "registry.gitlab.com/freedesktop-sdk/infrastructure/freedesktop-sdk-docker-images/bst2"


@unittest.skipUnless(os.environ.get("DAKOTA_OWNERSHIP_REAL_BST") == "1", "run via just test-ownership-buildstream")
class OwnershipBuildStreamTests(unittest.TestCase):
    def test_exact_integrated_layer_filtered_overlap_and_generated_owner(self):
        with tempfile.TemporaryDirectory(prefix="dakota-ownership-bst-") as temporary:
            work = Path(temporary)
            (work / "plugins").mkdir(); (work / "elements").mkdir(); (work / "cache").mkdir()
            for name in ("chunkah-ownership.py", "chunkah-ownership.yaml"):
                shutil.copy2(ROOT / "plugins" / name, work / "plugins" / name)
            (work / "project.conf").write_text(
                "name: fixture\nmin-version: 2.5\nelement-path: elements\n"
                "plugins:\n- origin: local\n  path: plugins\n  elements: [chunkah-ownership]\n"
            )
            for name, text in (("a", "old"), ("b", "winner")):
                path = work / "src" / name / "usr/bin"; path.mkdir(parents=True)
                (path / "shared").write_text(text)
            (work / "src/a/usr/bin/remove").write_text("remove")
            shell_root = work / "src/shell"
            shell_root.mkdir(parents=True)
            # Integration runs inside the composed root, so import the shell
            # and its exact runtime libraries from the pinned BST 2.8 image.
            runtime_files = [
                "/bin/bash",
                "/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2",
                "/usr/lib/x86_64-linux-gnu/libreadline.so.8",
                "/usr/lib/x86_64-linux-gnu/libtinfo.so.6",
                "/usr/lib/x86_64-linux-gnu/libc.so.6",
                "/usr/lib/x86_64-linux-gnu/libncursesw.so.6",
                "/usr/lib/x86_64-linux-gnu/libtinfow.so.6",
            ]
            container = subprocess.run(["podman", "create", IMAGE], check=True, text=True, capture_output=True).stdout.strip()
            try:
                for source in runtime_files:
                    destination = shell_root / source.lstrip("/")
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    subprocess.run(["podman", "cp", f"{container}:{source}", destination], check=True)
            finally:
                subprocess.run(["podman", "rm", container], check=True, stdout=subprocess.DEVNULL)
            os.symlink("bash", shell_root / "bin/sh")
            loader_link = shell_root / "lib64/ld-linux-x86-64.so.2"
            loader_link.parent.mkdir(parents=True)
            os.symlink("../usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2", loader_link)
            include = work / "src/a/usr/include"; include.mkdir(parents=True); (include / "a.h").write_text("header")
            for name in ("a", "b", "shell"):
                (work / "elements" / f"{name}.bst").write_text(
                    f"kind: import\nsources:\n- kind: local\n  path: src/{name}\n"
                    + ("public:\n  bst:\n    split-rules:\n      devel: [/usr/include/**]\n" if name == "a" else "")
                )
            (work / "elements/stack.bst").write_text("""kind: stack
depends: [shell.bst, a.bst, b.bst]
public:
  bst:
    integration-commands:
    - printf integrated-content > /usr/bin/shared
    - printf generated-content > /usr/bin/generated
""")
            (work / "elements/layer.bst").write_text("""kind: compose
build-depends: [stack.bst]
config:
  exclude: [devel]
""")
            (work / "elements/ownership.bst").write_text("""kind: chunkah-ownership
build-depends: [layer.bst, stack.bst]
config:
  layer-dependency: layer.bst
  provenance-dependencies: [stack.bst]
""")
            base = [
                "podman", "run", "--rm", "--privileged", "--device", "/dev/fuse",
                "--network=host", "--entrypoint", "bst",
                "-v", f"{work}:/workspace:rw",
                "-v", f"{work / 'cache'}:/root/.cache/buildstream:rw",
                "-w", "/workspace", IMAGE,
            ]
            subprocess.run(base + ["build", "ownership.bst"], check=True)
            subprocess.run(base + ["artifact", "checkout", "--no-integrate", "ownership.bst", "--directory", "/workspace/out"], check=True)
            subprocess.run(base + ["artifact", "checkout", "--no-integrate", "layer.bst", "--directory", "/workspace/layer-out"], check=True)

            out, layer = work / "out", work / "layer-out"
            self.assertFalse((out / "usr").exists(), "companion must not produce a rootfs")
            basis = json.loads((out / "ownership/basis.json").read_text())
            owners = {entry["path"]: entry for entry in basis["entries"]}
            self.assertEqual(basis["schema"], 3)
            self.assertRegex(basis["layer_artifact"], r"^fixture/layer/[0-9a-f]{64}$")
            self.assertEqual((layer / "usr/bin/shared").read_text(), "integrated-content")
            self.assertEqual(owners["/usr/bin/shared"]["component"], "b.bst")
            self.assertEqual(owners["/usr/bin/shared"]["producer"], "fixture:b.bst")
            self.assertEqual(owners["/usr/bin/generated"]["component"], "dakota.integration")
            self.assertEqual(owners["/usr/bin/remove"]["component"], "a.bst")
            self.assertNotIn("/usr/include/a.h", owners)
            self.assertEqual(basis["structure"]["usr/bin/shared"], "file")
            # The basis describes the exact cached layer realization rather
            # than independently running its integration commands.
            self.assertEqual(
                hashlib.sha256((layer / "usr/bin/shared").read_bytes()).hexdigest(),
                hashlib.sha256(b"integrated-content").hexdigest(),
            )


if __name__ == "__main__":
    unittest.main()
