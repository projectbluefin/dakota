"""Exercise the actual export recipe as a non-root sudo caller in isolation.

Only BST checkout is replaced with a prepared OCI fixture. Podman, sudo,
filesystem permissions, image mounts and the ownership validator are real.
No host sudo configuration is changed. Requires cached bst2 and Fedora images.
"""
from __future__ import annotations

import hashlib
import io
import json
import os
import shutil
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path

from scripts import ownership_metadata as metadata

REPO = Path(__file__).resolve().parents[1]
RUNNER = os.environ.get("BST2_IMAGE", "registry.gitlab.com/freedesktop-sdk/infrastructure/freedesktop-sdk-docker-images/bst2")


@unittest.skipUnless(os.environ.get("DAKOTA_OWNERSHIP_EXPORT_TEST") == "1", "explicit sudo/Podman fixture")
class ExportPrivilegeTests(unittest.TestCase):
    def test_nonroot_export_hashes_private_files_and_returns_owned_outputs(self):
        with tempfile.TemporaryDirectory(prefix="dakota-export-fixture-") as directory:
            tmp = Path(directory)
            layout = tmp / "layout"
            subprocess.run(["podman", "save", "--uncompressed", "--format", "oci-dir", "-o", str(layout),
                            "quay.io/fedora/fedora:42"], check=True)
            manifest, _ = metadata._manifest_from_layout(layout)
            blobdir = layout / "blobs/sha256"
            stream = io.BytesIO()
            with tarfile.open(fileobj=stream, mode="w") as archive:
                for name, data, mode in [("usr", None, 0o755), ("usr/lib", None, 0o755),
                                         ("root", None, 0o700),
                                         ("root/ownership-private", b"must be hashed with privilege\n", 0o600),
                                         ("usr/lib/os-release", b"NAME=Fixture\nVERSION_ID=0\nIMAGE_VERSION=0\n", 0o644)]:
                    entry = tarfile.TarInfo(name)
                    entry.mode, entry.uid, entry.gid, entry.mtime = mode, 0, 0, 1321009871
                    entry.type = tarfile.DIRTYPE if data is None else tarfile.REGTYPE
                    entry.size = len(data) if data is not None else 0
                    archive.addfile(entry, io.BytesIO(data) if data is not None else None)
            raw = stream.getvalue()
            digest = hashlib.sha256(raw).hexdigest()
            (blobdir / digest).write_bytes(raw)
            manifest["layers"].append({"mediaType": "application/vnd.oci.image.layer.v1.tar", "digest": "sha256:" + digest, "size": len(raw)})
            # Update diff_ids together with the layer descriptor to form a valid image.
            config = json.loads((blobdir / manifest["config"]["digest"].split(":")[1]).read_text())
            config["rootfs"]["diff_ids"].append("sha256:" + digest)
            config.setdefault("history", []).append({"created_by": "ownership privilege fixture"})
            config_raw = json.dumps(config).encode()
            config_digest = hashlib.sha256(config_raw).hexdigest()
            (blobdir / config_digest).write_bytes(config_raw)
            manifest["config"].update(digest="sha256:" + config_digest, size=len(config_raw))
            manifest_raw = json.dumps(manifest).encode()
            manifest_digest = hashlib.sha256(manifest_raw).hexdigest()
            (blobdir / manifest_digest).write_bytes(manifest_raw)
            (layout / "index.json").write_text(json.dumps({"schemaVersion": 2, "manifests": [{
                "mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:" + manifest_digest, "size": len(manifest_raw)}]}))
            tree, manifest_digest = metadata.oci_snapshot(layout)
            owners = {name: {"component": "fixture.bst", "producer": "fixture:fixture.bst", "interval": "monthly"}
                      for name, record in tree.items() if record["type"] in ("file", "symlink")}
            payload = metadata._final_payload(tree, owners, "fixture/layer/key", "0" * 64, "amd64", "default", manifest_digest)
            payload["os_release_lines"] = ["NAME=Fixture\n", "VERSION_ID=0\n", "IMAGE_VERSION=0\n"]
            metadata._write_json(layout / ".dakota/ownership-final.json", payload)

            shutil.copy2(REPO / "Justfile", tmp / "Justfile")
            # Use the explicit runner seam; do not rewrite the Justfile wrapper.
            (tmp / "bst-checkout").write_text('''#!/usr/bin/env bash
set -euo pipefail
[[ "$#" = 5 && "$1" = artifact && "$2" = checkout && "$3" = oci/bluefin.bst && "$4" = --directory && "$5" = /src/.build-out ]]
cp -a /work/layout /work/.build-out
''')
            (tmp / "bst-checkout").chmod(0o755)
            (tmp / "scripts").mkdir()
            shutil.copy2(REPO / "scripts/ownership_metadata.py", tmp / "scripts")
            (tmp / "work").mkdir()
            (tmp / "runtime").mkdir()
            (tmp / "run.sh").write_text('''#!/usr/bin/env bash
set -euo pipefail
trap 'chown -R 0:0 /work /var/tmp; chmod -R u+rwX /work /var/tmp' EXIT
cp -a /fixtures/Justfile /fixtures/scripts /fixtures/layout /fixtures/bst-checkout /work/
# The minimal build runner has passwd entries but no shadow database.
pwconv
useradd --create-home runner
mkdir -p /etc/sudoers.d
chmod 0755 /etc/sudoers.d
printf 'runner ALL=(ALL) NOPASSWD: ALL\\n' > /etc/sudoers.d/ownership-fixture
chmod 0440 /etc/sudoers.d/ownership-fixture
# This store and sudo policy exist only inside this disposable test container.
printf '[storage]\\ndriver="vfs"\\nrunroot="/run/containers/storage"\\ngraphroot="/var/lib/containers/storage"\\n' > /etc/containers/storage.conf
chown -R runner:runner /work
chmod 0755 /work
sudo -u runner env HOME=/home/runner bash <<'RUNNER'
set -euo pipefail
cd /work
export BST_RUNNER=/work/bst-checkout
cp Justfile Justfile.fixed
python3 - <<'PY'
from pathlib import Path
path = Path("Justfile")
text = path.read_text()
needle = "$SUDO_CMD python3 scripts/ownership_metadata.py rebind-exported"
assert text.count(needle) == 1
path.write_text(text.replace(needle, needle.removeprefix("$SUDO_CMD ")))
PY
if BUILD_IMAGE_NAME=ownership-fixture just export default > old-export.log 2>&1; then
    echo "old unprivileged validator unexpectedly succeeded" >&2; exit 1
fi
grep -q 'Permission denied' old-export.log
mv Justfile.fixed Justfile
BUILD_IMAGE_NAME=ownership-fixture just export default
ID=$(sudo podman inspect --format "{{.Id}}" ownership-fixture)
MOUNT=$(sudo podman image mount "$ID")
trap 'sudo podman image umount "$ID" >/dev/null 2>&1 || true' EXIT
if cat "$MOUNT/root/ownership-private" 2>/dev/null; then
    echo "fixture did not enforce the non-root permission boundary" >&2; exit 1
fi
sudo test -f "$MOUNT/root/ownership-private"
python3 - "$ID" <<"PY"
import json, os, pathlib, sys
folder=pathlib.Path(".build-ownership") / sys.argv[1]
for name in ["ownership-final.json", "fakecap-manifest.tsv", "image-id"]:
    assert (folder/name).stat().st_uid == os.getuid(), name
state=json.loads((folder/"ownership-final.json").read_text())
assert state["snapshot"]["root/ownership-private"]["mode"] == 0o600
assert state["image_id"] == sys.argv[1]
print("PASS: old validator failed; real sudo export returned user-owned metadata")
PY
sudo podman image umount "$ID"
trap - EXIT
# Exercise the real gaming-name selection, without building a gaming image.
python3 - <<'PY'
import json, pathlib
path = pathlib.Path("layout/.dakota/ownership-final.json")
state = json.loads(path.read_text())
state["variant"] = "gaming"
path.write_text(json.dumps(state))
PY
BUILD_GAMING=true BUILD_IMAGE_NAME=ownership-fixture just export default
ID=$(sudo podman inspect --format "{{.Id}}" ownership-fixture-gaming)
python3 - "$ID" <<'PY'
import json, pathlib, sys
state = json.loads((pathlib.Path(".build-ownership") / sys.argv[1] / "ownership-final.json").read_text())
assert state["variant"] == "gaming"
print("PASS: default gaming export uses the gaming sidecar identity")
PY
RUNNER
''')
            subprocess.run(["podman", "run", "--rm", "--pull=never", "--privileged", "--entrypoint", "/bin/bash",
                            "-v", f"{tmp}:/fixtures:ro", "-v", f"{tmp / 'work'}:/work:rw",
                            "-v", f"{tmp / 'runtime'}:/var/tmp:rw",
                            "-v", f"{shutil.which('just')}:/usr/local/bin/just:ro",
                            RUNNER, "/fixtures/run.sh"], check=True)


if __name__ == "__main__":
    unittest.main()
