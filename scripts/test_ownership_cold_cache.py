#!/usr/bin/env python3
"""Cold-pull exact local BST artifacts through a disposable local CAS server.

The source cache is mounted read-only, with disposable overlay writes for the
sender. The receiver cannot access it. Neither project remotes nor host image
storage are used by the receiver. Run explicitly via the Justfile recipe.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
RUNNER = os.environ.get("BST2_IMAGE", "registry.gitlab.com/freedesktop-sdk/infrastructure/freedesktop-sdk-docker-images/bst2")


def cleanup_resources(state, containers, output, cache, refs, fingerprints):
    """Attempt every cleanup step even when diagnostics or another step fails."""
    errors = []
    try:
        after = {ref: hashlib.sha256((cache / 'artifacts/refs' / ref).read_bytes()).hexdigest() for ref in refs}
        (output / "source-cache-after.json").write_text(json.dumps({
            "artifact_ref_sha256_after": after, "unchanged": after == fingerprints,
        }, indent=2) + "\n")
    except Exception as error:
        errors.append(f"recording cache fingerprints: {error}")
    # CID files also cover interruption before a foreground `podman run` returns.
    owned = set(containers)
    for name in ("server", "sender", "receiver"):
        try:
            cid = (state / f"{name}.cid").read_text().strip()
            if re.fullmatch(r"[0-9a-f]{64}", cid):
                owned.add(cid)
        except FileNotFoundError:
            pass
        except Exception as error:
            errors.append(f"reading {name} container ID: {error}")
    removal_failed = False
    for container in sorted(owned):
        try:
            with (output / f"container-{container}.log").open("w") as stream:
                subprocess.run(["podman", "logs", container], stdout=stream, stderr=subprocess.STDOUT)
        except Exception as error:
            errors.append(f"recording container log: {error}")
        try:
            subprocess.run(["podman", "rm", "-f", "--ignore", container], check=True, stdout=subprocess.DEVNULL)
        except Exception as error:
            removal_failed = True
            errors.append(f"removing container {container}: {error}")
    if removal_failed:
        errors.append(f"preserving temporary directory {state}: a container may still be using it")
    else:
        try:
            subprocess.run(["podman", "unshare", "rm", "-rf", "--", str(state)], check=True)
        except Exception as error:
            errors.append(f"removing temporary directory {state}: {error}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("default_ref")
    parser.add_argument("nvidia_ref")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    refs = [args.default_ref, args.nvidia_ref]
    for ref in refs:
        if not re.fullmatch(r"[\w.-]+/[\w.-]+/[0-9a-f]{64}", ref):
            parser.error("use exact project/element/64-hex-key artifact references")
    cache = Path.home() / ".cache/buildstream"
    fingerprints = {}
    for ref in refs:
        path = cache / "artifacts/refs" / ref
        fingerprints[ref] = hashlib.sha256(path.read_bytes()).hexdigest()
    if shutil.disk_usage(Path.home()).free < 80 * 1024**3:
        parser.error("at least 80 GiB free on the home filesystem is required")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    state = Path(tempfile.mkdtemp(prefix="dakota-cold-cache-", dir=Path.home()))
    containers = []

    def run(command, log=None):
        if log:
            with (output / log).open("w") as stream:
                return subprocess.run(command, check=True, stdout=stream, stderr=subprocess.STDOUT)
        return subprocess.run(command, check=True, text=True, capture_output=True)

    try:
        for name in ["server", "upper", "overlay-work", "receiver", "images", "work", "runtime", "project/elements"]:
            (state / name).mkdir(parents=True)
        (state / "project/project.conf").write_text("name: cold-check\nmin-version: 2.5\nelement-path: elements\n")
        for name, cachedir in [("sender", "/seed-cache"), ("receiver", "/state/receiver")]:
            (state / f"{name}.conf").write_text(f"""cachedir: {cachedir}
cache:
  quota: infinity
  reserved-disk-space: 2G
  pull-buildtrees: false
artifacts:
  override-project-caches: true
  servers:
  - url: http://127.0.0.1:11001
    push: {str(name == 'sender').lower()}
source-caches:
  override-project-caches: true
  servers: []
""")
        # Pin all containers in this test to the same already-cached runner ID.
        runner_id = run(["podman", "image", "inspect", "--format", "{{.Id}}", RUNNER]).stdout.strip()
        server = run(["podman", "run", "-d", "--cidfile", str(state / "server.cid"), "--pull=never", "--entrypoint", "buildbox-casd",
                      "-v", f"{state / 'server'}:/server:rw", runner_id,
                      "--bind=127.0.0.1:11001", "--quota-high=32G", "/server"]).stdout.strip()
        containers.append(server)
        for attempt in range(30):
            ready = subprocess.run(["podman", "exec", server, "python3", "-c",
                                    "import socket; socket.create_connection(('127.0.0.1',11001),1).close()"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if ready.returncode == 0:
                break
            time.sleep(1)
        else:
            raise RuntimeError("disposable CAS server did not become ready")
        (output / "source-cache-mount.json").write_text(json.dumps({
            "cache": str(cache), "access": "read-only", "sender_writes": "disposable overlay",
            "receiver_cache_initial_entries": list((state / "receiver").iterdir()),
            "artifact_refs": refs, "artifact_ref_sha256_before": fingerprints,
            "runner_id": runner_id, "server": server,
        }, indent=2) + "\n")
        (state / "seed.sh").write_text('''#!/usr/bin/env bash
set -euo pipefail
mkdir /seed-cache
mount -t overlay overlay -o lowerdir=/source-cache,upperdir=/state/upper,workdir=/state/overlay-work /seed-cache
trap 'umount /seed-cache' EXIT
cd /state/project
bst --no-interactive --config /state/sender.conf artifact push --deps none "$@"
''')
        run(["podman", "run", "--rm", "--pull=never", "--privileged", "--init",
             "--network", f"container:{server}", "--entrypoint", "/bin/bash",
             "-v", f"{cache}:/source-cache:ro", "-v", f"{state}:/state:rw",
             "--cidfile", str(state / "sender.cid"),
             runner_id, "/state/seed.sh", *refs], "seed.log")
        # Only ordinary source files enter the receiver workspace, never local
        # metadata outputs, original artifacts, or the original source cache.
        work = state / "work"
        (work / "scripts").mkdir()
        (work / "files/fakecap").mkdir(parents=True)
        shutil.copy2(REPO / "scripts/ownership_metadata.py", work / "scripts")
        shutil.copy2(REPO / "files/fakecap/fakecap-restore.c", work / "files/fakecap")
        # The minimal BST runner has no compiler. Build the same helper with
        # the host compiler, solely in the disposable workspace.
        run(["gcc", "-O2", "-o", str(work / "files/fakecap/fakecap-restore"),
             str(work / "files/fakecap/fakecap-restore.c")], "helper-build.log")
        shutil.copy2(REPO / "Justfile", work / "Justfile")
        (work / "bst-checkout").write_text('''#!/usr/bin/env bash
set -euo pipefail
[[ "$#" = 5 && "$1" = artifact && "$2" = checkout && "$3" = "$COLD_ELEMENT" && "$4" = --directory && "$5" = /src/.build-out ]]
exec bst --no-interactive --config /state/receiver.conf artifact checkout "$COLD_ARTIFACT" --deps none --no-integrate --directory /work/.build-out
''')
        (work / "bst-checkout").chmod(0o755)
        (state / "receive.sh").write_text('''#!/usr/bin/env bash
set -euo pipefail
# An isolated overlay store avoids sharing host images and avoids the
# quadratic storage cost of loading 120 layers with VFS. Both the image store
# and runtime scratch are bound to real home-backed directories.
printf '[storage]\\ndriver="overlay"\\nrunroot="/run/containers/storage"\\ngraphroot="/state/images"\\n' > /etc/containers/storage.conf
printf '[containers]\\nnetns="host"\\n' > /etc/containers/containers.conf
cd /state/project
test -z "$(ls -A /state/receiver)"
bst --no-interactive --config /state/receiver.conf artifact show "$@"
bst --no-interactive --config /state/receiver.conf artifact pull --deps none "$@"
bst --no-interactive --config /state/receiver.conf artifact show "$@"
cd /work
export BST_RUNNER=/work/bst-checkout
for variant in default nvidia; do
    export COLD_ARTIFACT="$1"
    export COLD_ELEMENT=oci/bluefin.bst
    [ "$variant" != nvidia ] || export COLD_ELEMENT=oci/bluefin-nvidia.bst
    shift
    echo "==> COLD ARTIFACT $variant $COLD_ARTIFACT"
    BUILD_IMAGE_NAME=ownership-cold just export "$variant"
    name=ownership-cold
    [ "$variant" != nvidia ] || name=ownership-cold-nvidia
    id=$(podman image inspect --format '{{.Id}}' "$name")
    cp ".build-ownership/$id/ownership-source.json" "/evidence/$variant-source.json"
    cp ".build-ownership/$id/ownership-final.json" "/evidence/$variant-final.json"
    just chunkify "localhost/$name:latest"
    podman image inspect "$name" > "/evidence/$variant-chunked.json"
    podman rmi "$name" "$id"
    rm -rf .build-ownership
    echo "PASS: $variant cold artifact exported and chunkified"
done
''')
        run(["podman", "run", "--rm", "--pull=never", "--privileged", "--init",
             "--network", f"container:{server}", "--entrypoint", "/bin/bash",
             "-v", f"{state / 'receiver'}:/state/receiver:rw",
             "-v", f"{state / 'images'}:/state/images:rw",
             "-v", f"{state / 'receiver.conf'}:/state/receiver.conf:ro",
             "-v", f"{state / 'project'}:/state/project:rw",
             "-v", f"{state / 'receive.sh'}:/receive.sh:ro",
             "-v", f"{work}:/work:rw", "-v", f"{state / 'runtime'}:/var/tmp:rw",
             "-v", f"{output}:/evidence:rw",
             "-v", f"{shutil.which('just')}:/usr/local/bin/just:ro",
             "--cidfile", str(state / "receiver.cid"),
             runner_id, "/receive.sh", *refs], "receive.log")
        after = {ref: hashlib.sha256((cache / 'artifacts/refs' / ref).read_bytes()).hexdigest() for ref in refs}
        if after != fingerprints:
            raise RuntimeError("source artifact reference fingerprints changed")
    finally:
        errors = cleanup_resources(state, containers, output, cache, refs, fingerprints)
        for error in errors:
            print(f"cold-cache cleanup: {error}", file=sys.stderr)
        if errors and sys.exc_info()[0] is None:
            raise RuntimeError("cold-cache cleanup failed; see diagnostics above")
    (output / "result.json").write_text(json.dumps({"status": "passed", "artifact_refs": refs,
        "source_reference_fingerprints_unchanged": True, "source_cache_read_only": True,
        "receiver_source_cache_mounted": False, "builds_run": 0,
        "variants_exported_and_chunkified": ["default", "nvidia"]}, indent=2) + "\n")
    print(f"PASS: cold artifact pull/export/chunkify; evidence: {output}")


if __name__ == "__main__":
    main()
