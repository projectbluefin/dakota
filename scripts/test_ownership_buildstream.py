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
    def test_inherits_companion_pulled_with_remote_execution_storage(self):
        # All producers are command-free: exercise real lazy remote CAS reads
        # without requiring a worker, credentials, or the host BuildStream cache.
        with tempfile.TemporaryDirectory(prefix="dakota-ownership-remote-") as temporary:
            work = Path(temporary)
            for directory in ("plugins", "elements"):
                (work / directory).mkdir(parents=True)
            for name in ("chunkah-ownership.py", "chunkah-ownership.yaml"):
                shutil.copy2(ROOT / "plugins" / name, work / "plugins" / name)
            # Generate payload only at build time. A local source would import
            # its bytes during graph loading, accidentally warming the consumer.
            (work / "plugins/fixture-payload.py").write_text('''from buildstream import Element
class Payload(Element):
    BST_MIN_VERSION = "2.5"
    BST_RUN_COMMANDS = False
    def configure(self, node):
        node.validate_keys([])
    def get_unique_key(self):
        return 1
    def preflight(self):
        pass
    def configure_sandbox(self, sandbox):
        pass
    def stage(self, sandbox):
        pass
    def assemble(self, sandbox):
        root = sandbox.get_virtual_directory()
        root.open_directory("usr/bin", create=True)
        with root.open_file("usr/bin/tool", mode="w") as output:
            output.write("fixture\\n")
        return "/"
def setup():
    return Payload
''')
            (work / "project.conf").write_text(
                "name: fixture\nmin-version: 2.5\nelement-path: elements\n"
                "plugins:\n- origin: local\n  path: plugins\n"
                "  elements: [chunkah-ownership, fixture-payload]\n"
            )
            (work / "elements/component.bst").write_text("kind: fixture-payload\n")
            (work / "elements/layer.bst").write_text(
                "kind: filter\nbuild-depends: [component.bst]\n"
            )
            (work / "elements/companion.bst").write_text(
                "kind: chunkah-ownership\nbuild-depends: [layer.bst, component.bst]\n"
                "config:\n  layer-dependency: layer.bst\n"
                "  provenance-dependencies: [component.bst]\n"
            )
            (work / "elements/parent-layer.bst").write_text(
                "kind: filter\nbuild-depends: [layer.bst]\n"
            )
            (work / "elements/parent.bst").write_text(
                "kind: chunkah-ownership\nbuild-depends: [parent-layer.bst, layer.bst, companion.bst]\n"
                "config:\n  layer-dependency: parent-layer.bst\n"
                "  provenance-dependencies: [layer.bst]\n"
                "  metadata-dependencies: [companion.bst]\n"
                "  inherit-from-components: [layer.bst]\n"
            )
            for name in ("producer", "consumer"):
                (work / f"{name}.conf").write_text(
                    f"cachedir: /workspace/{name}-cache\n"
                    "artifacts:\n  override-project-caches: true\n  servers:\n"
                    "  - url: http://127.0.0.1:11001\n"
                    f"    push: {str(name == 'producer').lower()}\n"
                    "source-caches:\n  override-project-caches: true\n  servers: []\n"
                    + ("cache:\n  storage-service:\n    url: http://127.0.0.1:11001\n"
                       "remote-execution:\n"
                       "  execution-service:\n    url: http://127.0.0.1:11001\n"
                       "  storage-service:\n    url: http://127.0.0.1:11001\n"
                       if name == "consumer" else "")
                )
            (work / "run.sh").write_text('''#!/usr/bin/env bash
set -euo pipefail
buildbox-casd --bind=127.0.0.1:11001 /workspace/remote > /workspace/casd.log 2>&1 &
server=$!
trap 'kill "$server"; wait "$server" || true' EXIT
python3 - <<'PY'
import socket, time
for attempt in range(100):
    try:
        socket.create_connection(('127.0.0.1', 11001), 1).close()
        break
    except OSError:
        time.sleep(0.1)
else:
    raise RuntimeError("fixture CAS server did not start")
PY
bst --no-interactive --config producer.conf build companion.bst
bst --no-interactive --config producer.conf artifact push --deps all companion.bst
bst --no-interactive --config producer.conf artifact checkout --no-integrate companion.bst --directory seed
sha256sum seed/ownership/basis.json | cut -d' ' -f1 > companion-digest
# Nothing from the producer cache is mounted or copied into the consumer cache.
bst --no-interactive --config consumer.conf artifact pull --deps all companion.bst
digest=$(cat companion-digest)
blob="consumer-cache/cas/objects/${digest:0:2}/${digest:2}"
test ! -e "$blob" || { echo "fixture unexpectedly hydrated companion before build" >&2; exit 1; }
echo "PASS: pulled companion has no local JSON blob"
payload_digest=$(printf 'fixture\\n' | sha256sum | cut -d' ' -f1)
payload_blob="consumer-cache/cas/objects/${payload_digest:0:2}/${payload_digest:2}"
test ! -e "$payload_blob"
bst --no-interactive --config consumer.conf build parent.bst
test -f "$blob"
# Reading the companion must not download the composed root's file payloads.
test ! -e "$payload_blob"
echo "PASS: parent build fetched metadata, not rootfs payloads"
bst --no-interactive --config consumer.conf artifact checkout --no-integrate parent.bst --directory result
''')
            runner = subprocess.run(
                ["podman", "image", "inspect", "--format", "{{.Id}}", IMAGE],
                check=True, text=True, capture_output=True,
            ).stdout.strip()
            result = subprocess.run(
                ["podman", "run", "--rm", "--pull=never", "--privileged",
                 "--entrypoint", "/bin/bash", "-v", f"{work}:/workspace:rw",
                 "-w", "/workspace", runner, "run.sh"],
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("PASS: pulled companion has no local JSON blob", result.stdout)
            self.assertIn("PASS: parent build fetched metadata, not rootfs payloads", result.stdout)
            basis = json.loads((work / "result/ownership/basis.json").read_text())
            owner = next(entry for entry in basis["entries"] if entry["path"] == "/usr/bin/tool")
            self.assertEqual(owner["component"], "component.bst")
            self.assertEqual(owner["producer"], "fixture:component.bst")
            print("PASS: remote-only companion inherited during a real parent build")

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
