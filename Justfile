# List available commands
[group('info')]
default:
    @just --list

# ── Configuration ─────────────────────────────────────────────────────
export image_name := env("BUILD_IMAGE_NAME", "dakota")
export image_tag := env("BUILD_IMAGE_TAG", "latest")

# Gaming variant: adds the gaming/ stack and selects the OGC kernel.
# Non-gaming variants use the freedesktop-sdk stable kernel. Applies to
# every bst invocation here; exported podman refs get a -gaming suffix
# so builds don't collide.
export gaming := env("BUILD_GAMING", "false")
export base_dir := env("BUILD_BASE_DIR", ".")
export filesystem := env("BUILD_FILESYSTEM", "btrfs")

# BuildStream container image used by local runs and CI.
# Leave it unset to use the upstream image default instead of a repo-local digest pin.
export bst2_image := env("BST2_IMAGE", "registry.gitlab.com/freedesktop-sdk/infrastructure/freedesktop-sdk-docker-images/bst2")

# VM settings
export vm_ram := env("VM_RAM", "8192")
export vm_cpus := env("VM_CPUS", "4")

# OCI metadata (dynamic labels)
export OCI_IMAGE_CREATED := env("OCI_IMAGE_CREATED", "")
export OCI_IMAGE_REVISION := env("OCI_IMAGE_REVISION", "")
export OCI_IMAGE_VERSION := env("OCI_IMAGE_VERSION", "latest")

# ── BuildStream wrapper ──────────────────────────────────────────────
# Runs any bst command inside the bst2 container via podman.
# Defaults to baseline x86_64 (`-o x86_64_v3 false`) so local runs match CI
# and reuse artifacts published by gnome-build-meta and freedesktop-sdk.
# Set BST_FLAGS to append flags (e.g. --config ...).
# Set BST_FLAGS_OVERRIDE to replace all default/appended flags.
# Usage: just bst build oci/bluefin.bst
#        just bst show oci/bluefin.bst
#        BST_FLAGS="--config /src/buildstream-ci.conf" just bst build oci/bluefin.bst
[group('dev')]
bst *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "${HOME}/.cache/buildstream"
    DEFAULT_BST_FLAGS="-o x86_64_v3 false --no-interactive"
    if [ -n "${BST_FLAGS_OVERRIDE:-}" ]; then
        EFFECTIVE_BST_FLAGS="${BST_FLAGS_OVERRIDE}"
    else
        EFFECTIVE_BST_FLAGS="${BST_FLAGS:-}"
        if [[ ! " ${EFFECTIVE_BST_FLAGS} " =~ [[:space:]]-o[[:space:]]+x86_64_v3[[:space:]]+(true|false)([[:space:]]|$) ]]; then
            EFFECTIVE_BST_FLAGS="${DEFAULT_BST_FLAGS} ${EFFECTIVE_BST_FLAGS}"
        fi
        if [[ ! " ${EFFECTIVE_BST_FLAGS} " =~ [[:space:]]--no-interactive([[:space:]]|$) ]]; then
            EFFECTIVE_BST_FLAGS="${EFFECTIVE_BST_FLAGS} --no-interactive"
        fi
        if [[ ! " ${EFFECTIVE_BST_FLAGS} " =~ [[:space:]]-o[[:space:]]+gaming[[:space:]]+(true|false)([[:space:]]|$) ]]; then
            EFFECTIVE_BST_FLAGS="${EFFECTIVE_BST_FLAGS} -o gaming {{gaming}}"
        fi
    fi

    # BST_FLAGS allows appending --no-interactive, --config, etc.
    # BST_PODMAN_EXTRA_ARGS allows extra podman flags (e.g. CI mounts a
    # hotfixed BST module over the image copy). Word-splitting is
    # intentional here (flags are space-separated).
    # shellcheck disable=SC2086
    podman run --rm \
        --privileged \
        --device /dev/fuse \
        --network=host \
        ${BST_PODMAN_EXTRA_ARGS:-} \
        -v "{{justfile_directory()}}:/src:rw" \
        -v "${HOME}/.cache/buildstream:/root/.cache/buildstream:rw" \
        -w /src \
        "{{bst2_image}}" \
        bash -c 'bst --colors "$@"' -- ${EFFECTIVE_BST_FLAGS} {{ARGS}}

# The ONLY recipe CI runs directly (.github/workflows/validate.yml).
# New python test suites must be registered here to be enforced; anything
# added to `validate` below runs on developer machines only.
[group('dev')]
check-publish-workflow:
    python3 scripts/check_publish_workflow.py
    python3 -m unittest scripts.test_check_publish_workflow
    python3 -m unittest scripts.test_gen_filemap
    python3 -m unittest scripts.test_image_variants

[group('dev')]
monitor-pipeline BUILD_RUN_ID="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{BUILD_RUN_ID}}" ]; then
        echo "usage: just monitor-pipeline BUILD_RUN_ID=<run-id>" >&2
        exit 2
    fi
    python3 files/monitor_pipeline.py --build-run-id "{{BUILD_RUN_ID}}"

# Local convenience wrapper. CI does NOT run this recipe; it runs
# `check-publish-workflow` plus its own bst show steps. Do not register
# CI-facing checks here.
[group('dev')]
validate:
    just check-publish-workflow
    just test-render-card
    just bst show --deps all oci/bluefin.bst
    just bst show --deps all oci/bluefin-nvidia.bst

# Unit tests for .github/scripts/render_card.py.
[group('dev')]
test-render-card:
    python3 -m unittest scripts.test_render_card

# Verify the local freedesktop-sdk patch queue matches its committed
# manifest, offline. The manifest is written by `just patch-sync` (the only
# step that contacts gitlab.gnome.org), so validate never depends on
# upstream uptime.
[group('dev')]
patch-drift-check:
    #!/usr/bin/env bash
    set -euo pipefail

    gbm_ref=$(awk '/^[[:space:]]*ref: / { print $2; exit }' elements/gnome-build-meta.bst)
    if [[ ! "$gbm_ref" =~ -g([0-9a-f]{40})$ ]]; then
        echo "ERROR: could not extract GBM commit SHA from elements/gnome-build-meta.bst ref: ${gbm_ref}" >&2
        exit 1
    fi
    export gbm_sha="${BASH_REMATCH[1]}"
    python3 - <<'EOF'
    import hashlib, json, os, sys

    manifest_path = "patches/freedesktop-sdk.manifest.json"
    local_dir = "patches/freedesktop-sdk"
    gbm_sha = os.environ["gbm_sha"]

    if not os.path.exists(manifest_path):
        sys.exit(f"ERROR: {manifest_path} missing - run `just patch-sync`")
    m = json.load(open(manifest_path))

    if m["gnome-build-meta-sha"] != gbm_sha:
        sys.exit(
            "ERROR: junction pins GBM %s but patches were synced for %s - run `just patch-sync`"
            % (gbm_sha, m["gnome-build-meta-sha"])
        )

    local = {
        f: hashlib.sha256(open(os.path.join(local_dir, f), "rb").read()).hexdigest()
        for f in sorted(os.listdir(local_dir))
        if os.path.isfile(os.path.join(local_dir, f))
    }
    status = 0
    for f in sorted(set(m["files"]) - set(local)):
        print(f"ERROR: {f} listed in manifest but missing locally", file=sys.stderr); status = 1
    for f in sorted(set(local) - set(m["files"])):
        print(f"ERROR: {f} present locally but not in manifest", file=sys.stderr); status = 1
    for f in sorted(set(local) & set(m["files"])):
        if local[f] != m["files"][f]:
            print(f"ERROR: {f} differs from manifest", file=sys.stderr); status = 1
    if status:
        sys.exit("ERROR: patch queue drifted from manifest - run `just patch-sync` after junction bumps")
    print(f"OK: patches/freedesktop-sdk matches manifest for GBM {gbm_sha} ({len(local)} files)")
    EOF

# Re-sync patches/freedesktop-sdk (and its manifest) from gnome-build-meta
# at the pinned junction sha. The one place upstream is contacted; run it
# after every gnome-build-meta junction bump.
[group('dev')]
patch-sync:
    #!/usr/bin/env bash
    set -euo pipefail

    gbm_ref=$(awk '/^[[:space:]]*ref: / { print $2; exit }' elements/gnome-build-meta.bst)
    if [[ ! "$gbm_ref" =~ -g([0-9a-f]{40})$ ]]; then
        echo "ERROR: could not extract GBM commit SHA from elements/gnome-build-meta.bst ref: ${gbm_ref}" >&2
        exit 1
    fi
    export gbm_sha="${BASH_REMATCH[1]}"

    files_api="https://gitlab.gnome.org/api/v4/projects/GNOME%2Fgnome-build-meta/repository/files"
    tree_api="https://gitlab.gnome.org/api/v4/projects/GNOME%2Fgnome-build-meta/repository/tree?path=patches/freedesktop-sdk&ref=${gbm_sha}&per_page=100"
    mapfile -t patch_files < <(curl -fsSL "$tree_api" \
        | python3 -c 'import json, sys; [print(i["name"]) for i in json.load(sys.stdin) if i["type"] == "blob"]')
    if [ "${#patch_files[@]}" -eq 0 ]; then
        echo "ERROR: empty patches/freedesktop-sdk listing at gnome-build-meta @ ${gbm_sha}" >&2
        exit 1
    fi
    rm -f patches/freedesktop-sdk/*
    for f in "${patch_files[@]}"; do
        encoded=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$f")
        curl -fsSL "${files_api}/patches%2Ffreedesktop-sdk%2F${encoded}/raw?ref=${gbm_sha}" \
            -o "patches/freedesktop-sdk/${f}"
    done

    python3 - <<'EOF'
    import hashlib, json, os

    d = "patches/freedesktop-sdk"
    files = {
        f: hashlib.sha256(open(os.path.join(d, f), "rb").read()).hexdigest()
        for f in sorted(os.listdir(d))
        if os.path.isfile(os.path.join(d, f))
    }
    manifest = {
        "comment": "Written by `just patch-sync`; verified offline by `just patch-drift-check`.",
        "gnome-build-meta-sha": os.environ["gbm_sha"],
        "files": files,
    }
    with open("patches/freedesktop-sdk.manifest.json", "w") as fh:
        json.dump(manifest, fh, indent=2, sort_keys=True)
        fh.write("\n")
    print(f"Synced {len(files)} patches and manifest for GBM {os.environ['gbm_sha']}")
    EOF

# ── Build ─────────────────────────────────────────────────────────────
# Build the OCI image and load it into podman.
#
# Variant selects which top-level OCI element to build:
#   all     → both default and nvidia, sequentially  (refs below)
#   default → oci/bluefin.bst                        ({{image_name}}:{{image_tag}})
#   nvidia  → oci/bluefin-nvidia.bst                 ({{image_name}}-nvidia:{{image_tag}})
#
# Usage:
#   just build              # builds BOTH variants (default + nvidia)
#   just build default      # only default bluefin variant
#   just build nvidia       # only nvidia variant
#
# When variant=all we run the per-variant build recursively so each one
# also runs its own export, leaving two podman refs:
# dakota:latest and dakota-nvidia:latest.
[group('build')]
build variant="all":
    #!/usr/bin/env bash
    set -euo pipefail

    if [ "{{variant}}" = "all" ]; then
        just build default
        if [ "${BUILD_SKIP_NVIDIA:-}" != "1" ]; then
            just build nvidia
        else
            echo "==> Skipping nvidia variant (BUILD_SKIP_NVIDIA=1)"
        fi
        exit 0
    fi

    case "{{variant}}" in
        default) ELEMENT="oci/bluefin.bst" ;;
        nvidia)  ELEMENT="oci/bluefin-nvidia.bst" ;;
        *) echo "ERROR: unknown variant '{{variant}}' (expected: all | default | nvidia)" >&2; exit 1 ;;
    esac

    echo "==> Building $ELEMENT with BuildStream (inside bst2 container)..."
    just bst build "$ELEMENT"

    just export {{variant}}

# ── Export ─────────────────────────────────────────────────────────────
# Checkout the built OCI image from BuildStream and load it into podman.
# Assumes the matching `just bst build` has already completed.
# Used by: `just build` (after building) and CI (as a separate step).
#
# Uses SUDO_CMD to handle root vs non-root: CI runs as root (no sudo),
# local dev needs sudo for podman access to containers-storage.
[group('build')]
export variant="default":
    #!/usr/bin/env bash
    set -euo pipefail

    case "{{variant}}" in
        default) ELEMENT="oci/bluefin.bst";        FINAL_NAME="{{image_name}}" ;;
        nvidia)  ELEMENT="oci/bluefin-nvidia.bst"; FINAL_NAME="{{image_name}}-nvidia" ;;
        *) echo "ERROR: unknown variant '{{variant}}' (expected: default | nvidia)" >&2; exit 1 ;;
    esac
    if [ "{{gaming}}" = "true" ]; then
        FINAL_NAME="${FINAL_NAME}-gaming"
    fi
    FINAL_TAG="{{image_tag}}"

    # Use sudo unless already root (CI runners are root)
    SUDO_CMD=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO_CMD="sudo"
    fi

    echo "==> Exporting OCI image ($ELEMENT → ${FINAL_NAME}:${FINAL_TAG})..."
    rm -rf .build-out
    just bst artifact checkout "$ELEMENT" --directory /src/.build-out

    # Load the multi-layer OCI image and squash into a single layer.
    # BuildStream produces separate layers (platform + gnomeos + bluefin);
    # bootc and registry distribution work better with one squashed layer.
    # Using podman (not skopeo) ensures the squashed view is preserved on push.
    echo "==> Loading and squashing OCI image..."
    IMAGE_ID=$($SUDO_CMD podman pull -q oci:.build-out)
    rm -rf .build-out

    # Build label arguments for dynamic OCI metadata
    LABEL_ARGS=""
    if [ -n "${OCI_IMAGE_CREATED}" ]; then
        LABEL_ARGS="${LABEL_ARGS} --label org.opencontainers.image.created=${OCI_IMAGE_CREATED}"
    fi
    if [ -n "${OCI_IMAGE_REVISION}" ]; then
        LABEL_ARGS="${LABEL_ARGS} --label org.opencontainers.image.revision=${OCI_IMAGE_REVISION}"
    fi
    if [ -n "${OCI_IMAGE_VERSION}" ]; then
        LABEL_ARGS="${LABEL_ARGS} --label org.opencontainers.image.version=${OCI_IMAGE_VERSION}"
    fi

    # Squash, inject build-date VERSION_ID, and apply dynamic labels.
    # BST has no string option type, so VERSION_ID is set to "0" in os-release.bst
    # and replaced here at export time — after the BST cache key is already fixed.
    # Reverts the buildah mount+commit approach from f8b80d4: buildah is not
    # available in quay.io/podman/stable (breaks local builds and Argo pipeline)
    # and the multi-layer output breaks composefs xattr injection in chunka.
    # Fixes: projectbluefin/dakota#841 (boot failure on :testing 2026-06-13)
    DATE_TAG="$(date -u +%Y%m%d)"
    # Preserve the deterministic source mtimes. sed -i changes the parent
    # directory mtime, which otherwise invalidates every Chunkah layer that
    # carries /usr/lib metadata even when its component files are unchanged.
    # shellcheck disable=SC2016,SC2086
    printf 'FROM %s\nRUN OS_RELEASE_MTIME="$(stat -c %%y /usr/lib/os-release)" \\\n    && USR_LIB_MTIME="$(stat -c %%y /usr/lib)" \\\n    && sed -i "s/^VERSION_ID=.*/VERSION_ID=\\"%s\\"/" /usr/lib/os-release \\\n    && sed -i "s/^IMAGE_VERSION=.*/IMAGE_VERSION=\\"%s\\"/" /usr/lib/os-release \\\n    && touch -d "$OS_RELEASE_MTIME" /usr/lib/os-release \\\n    && touch -d "$USR_LIB_MTIME" /usr/lib\n' "$IMAGE_ID" "$DATE_TAG" "$DATE_TAG" \
        | $SUDO_CMD podman build --pull=never --security-opt label=type:unconfined_t --squash-all ${LABEL_ARGS} -t "${FINAL_NAME}:${FINAL_TAG}" -f - .
    $SUDO_CMD podman rmi "$IMAGE_ID" || true

    echo "==> Export complete. Image loaded as ${FINAL_NAME}:${FINAL_TAG}"
    $SUDO_CMD podman images | grep -E "{{image_name}}|REPOSITORY" || true

# Push exported image to a local zot registry for lab testing.
[group('dev')]
push-local registry="localhost:5000":
    #!/usr/bin/env bash
    set -euo pipefail

    SUDO_CMD=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO_CMD="sudo"
    fi

    SOURCE_REF="{{image_name}}:{{image_tag}}"
    TARGET_REF="{{registry}}/{{image_name}}:{{image_tag}}"

    if ! $SUDO_CMD podman image exists "$SOURCE_REF"; then
        echo "ERROR: Image '$SOURCE_REF' not found in podman." >&2
        echo "Run 'just export' first." >&2
        exit 1
    fi

    trap '$SUDO_CMD podman rmi "$TARGET_REF" >/dev/null 2>&1 || true' EXIT

    echo "==> Tagging $SOURCE_REF as $TARGET_REF"
    $SUDO_CMD podman tag "$SOURCE_REF" "$TARGET_REF"
    echo "==> Pushing $TARGET_REF"
    $SUDO_CMD podman push "$TARGET_REF"

# ── Clean ─────────────────────────────────────────────────────────────
# Remove generated artifacts (disk image, OVMF vars, build output).
[group('build')]
clean:
    rm -f bootable.raw .ovmf-vars.fd
    rm -rf .build-out

# ── Containerfile build (lint helper only) ───────────────────────────
# This is not Dakota's package assembly path.
# Real image content changes happen in BuildStream elements and `just build`.
[group('build')]
build-containerfile $image_name=image_name:
    sudo podman build --security-opt label=type:unconfined_t --squash-all -t "${image_name}:latest" .

# ── bootc helper ─────────────────────────────────────────────────────
[group('dev')]
bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /var/lib/containers:/var/lib/containers \
        -v /dev:/dev \
        -v "{{base_dir}}:/data" \
        --security-opt label=type:unconfined_t \
        "{{image_name}}:{{image_tag}}" bootc {{ARGS}}

# ── Generate bootable disk image ─────────────────────────────────────
# Variant selects which loaded image to install (default | nvidia).
# Mirrors `just build` / `just export`'s tag scheme.
[group('test')]
generate-bootable-image variant="default" $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    set -euo pipefail

    case "{{variant}}" in
        default) FINAL_NAME="{{image_name}}" ;;
        nvidia)  FINAL_NAME="{{image_name}}-nvidia" ;;
        *) echo "ERROR: unknown variant '{{variant}}' (expected: default | nvidia)" >&2; exit 1 ;;
    esac
    if [ "{{gaming}}" = "true" ]; then
        FINAL_NAME="${FINAL_NAME}-gaming"
    fi

    REF="${FINAL_NAME}:{{image_tag}}"
    if ! sudo podman image exists "$REF"; then
        echo "ERROR: Image '$REF' not found in podman." >&2
        echo "Run 'just build {{variant}}' first to build and export the OCI image." >&2
        exit 1
    fi

    if [ ! -e "${base_dir}/bootable.raw" ] ; then
        echo "==> Creating 30G sparse disk image..."
        fallocate -l 30G "${base_dir}/bootable.raw"
    fi

    echo "==> Installing $REF to disk image via bootc..."
    BUILD_IMAGE_NAME="$FINAL_NAME" just bootc install to-disk \
        --via-loopback /data/bootable.raw \
        --filesystem "${filesystem}" \
        --wipe \
        --composefs-backend \
        --bootloader systemd \
        --karg systemd.firstboot=no \
        --karg splash \
        --karg quiet

    echo "==> Bootable disk image ready: ${base_dir}/bootable.raw"
    sync

    # Remove stale qcow2 so boot-vm uses the fresh raw image
    rm -f "${base_dir}/bootable.qcow2"

# ── Boot VM ──────────────────────────────────────────────────────────
# Boot the raw disk image.
# If qemu-system-x86_64 is installed, runs natively (UEFI/OVMF).
# Otherwise, falls back to running via docker.io/qemux/qemu-docker.
[group('test')]
boot-vm $base_dir=base_dir:
    #!/usr/bin/env bash
    set -euo pipefail

    # Resolve absolute path for Docker volume mount
    DISK=$(realpath "{{base_dir}}/bootable.raw")
    if [ ! -e "$DISK" ]; then
        echo "ERROR: ${DISK} not found. Run 'just generate-bootable-image' first." >&2
        exit 1
    fi

    # Check for native QEMU
    if command -v qemu-system-x86_64 &>/dev/null; then
        echo "==> Using native qemu-system-x86_64..."

        # Auto-detect OVMF firmware paths
        OVMF_CODE=""
        for candidate in \
            /usr/share/edk2/ovmf/OVMF_CODE.fd \
            /usr/share/OVMF/OVMF_CODE.fd \
            /usr/share/OVMF/OVMF_CODE_4M.fd \
            /usr/share/edk2/x64/OVMF_CODE.4m.fd \
            /usr/share/qemu/OVMF_CODE.fd; do
            if [ -f "$candidate" ]; then
                OVMF_CODE="$candidate"
                break
            fi
        done
        if [ -z "$OVMF_CODE" ]; then
            echo "ERROR: OVMF firmware not found. Install edk2-ovmf (Fedora) or ovmf (Debian/Ubuntu)." >&2
            exit 1
        fi

        # OVMF_VARS must be writable -- use a local copy
        OVMF_VARS="{{base_dir}}/.ovmf-vars.fd"
        if [ ! -e "$OVMF_VARS" ]; then
            OVMF_VARS_SRC=""
            for candidate in \
                /usr/share/edk2/ovmf/OVMF_VARS.fd \
                /usr/share/OVMF/OVMF_VARS.fd \
                /usr/share/OVMF/OVMF_VARS_4M.fd \
                /usr/share/edk2/x64/OVMF_VARS.4m.fd \
                /usr/share/qemu/OVMF_VARS.fd; do
                if [ -f "$candidate" ]; then
                    OVMF_VARS_SRC="$candidate"
                    break
                fi
            done
            if [ -z "$OVMF_VARS_SRC" ]; then
                echo "ERROR: OVMF_VARS not found alongside OVMF_CODE." >&2
                exit 1
            fi
            cp "$OVMF_VARS_SRC" "$OVMF_VARS"
        fi

        echo "==> Booting ${DISK} in QEMU (UEFI, KVM)..."
        echo "    Firmware: ${OVMF_CODE}"
        echo "    RAM: {{vm_ram}}M, CPUs: {{vm_cpus}}"
        echo "    Serial debug shell on ttyS1 available via QEMU monitor"
        echo ""

        qemu-system-x86_64 \
            -enable-kvm \
            -m "{{vm_ram}}" \
            -cpu host \
            -smp "{{vm_cpus}}" \
            -drive file="${DISK}",format=raw,if=virtio \
            -drive if=pflash,format=raw,readonly=on,file="${OVMF_CODE}" \
            -drive if=pflash,format=raw,file="${OVMF_VARS}" \
            -device virtio-vga \
            -display gtk \
            -device virtio-keyboard \
            -device virtio-mouse \
            -device virtio-net-pci,netdev=net0 \
            -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
            -chardev stdio,id=char0,mux=on,signal=off \
            -serial chardev:char0 \
            -serial chardev:char0 \
            -mon chardev=char0

    else
        echo "==> qemu-system-x86_64 not found, falling back to docker.io/qemux/qemu-docker..."

        # Check for qcow2 image, prefer it if exists
        BOOT_MOUNT="/boot.img"
        if [ -e "{{base_dir}}/bootable.qcow2" ]; then
            DISK=$(realpath "{{base_dir}}/bootable.qcow2")
            BOOT_MOUNT="/boot.qcow2"
        fi

        # Determine which port to use (adapted from user snippet)
        port=8006
        while grep -q :${port} <<< $(ss -tunalp); do
            port=$(( port + 1 ))
        done
        echo "==> Web/VNC accessible at http://localhost:${port}"

        # Try to open browser
        xdg-open "http://localhost:${port}" &>/dev/null || true

        # Run via podman
        # Per docs: mounting to /boot.img or /boot.qcow2 bypasses BOOT and uses the local file directly
        podman run \
            --rm --privileged \
            --device /dev/kvm \
            --pull=always \
            --publish "127.0.0.1:${port}:8006" \
            --publish "127.0.0.1:2222:22" \
            --env "USER_PORTS=22" \
            --env "NETWORK=user" \
            --env "CPU_CORES={{vm_cpus}}" \
            --env "RAM_SIZE={{vm_ram}}" \
            --env "TPM=y" \
            --env "BOOT_MODE=${BOOT_MODE:-uefi}" \
            --env "ARGUMENTS=-snapshot" \
            --volume "${DISK}:${BOOT_MOUNT}" \
            ghcr.io/qemus/qemu:latest
    fi

# ── Convert to qcow2 ──────────────────────────────────────────────────
# Convert raw disk image to qcow2 format for better performance/compat.
[group('test')]
convert-to-qcow2 $base_dir=base_dir:
    #!/usr/bin/env bash
    set -euo pipefail

    RAW="{{base_dir}}/bootable.raw"
    QCOW2="{{base_dir}}/bootable.qcow2"

    if [ ! -e "$RAW" ]; then
        echo "ERROR: ${RAW} not found. Run 'just generate-bootable-image' first." >&2
        exit 1
    fi

    echo "==> Converting ${RAW} to ${QCOW2}..."

    if command -v qemu-img &>/dev/null; then
        qemu-img convert -f raw -O qcow2 "$RAW" "$QCOW2"
    else
        # Use the same container image to run qemu-img
        echo "    Using containerized qemu-img..."
        podman run --rm \
            -v "{{base_dir}}:/data" \
            --entrypoint qemu-img \
            ghcr.io/qemus/qemu:latest \
            convert -f raw -O qcow2 "/data/bootable.raw" "/data/bootable.qcow2"
    fi
    echo "==> Conversion complete: ${QCOW2}"

# ── Show me the future ────────────────────────────────────────────────
# The full end-to-end: build the OCI image, install it to a bootable
# disk, and launch it in a QEMU VM. One command to rule them all.
# Uses charm.sh gum for styled output when available.
[group('test')]
show-me-the-future:
    #!/usr/bin/env bash
    set -euo pipefail

    # ── Helpers ───────────────────────────────────────────────────
    HAS_GUM=false
    command -v gum &>/dev/null && [[ -t 1 ]] && HAS_GUM=true

    OVERALL_START=$SECONDS

    format_time() {
        local secs=$1
        if (( secs >= 3600 )); then
            printf '%dh %02dm %02ds' $((secs / 3600)) $(((secs % 3600) / 60)) $((secs % 60))
        elif (( secs >= 60 )); then
            printf '%dm %02ds' $((secs / 60)) $((secs % 60))
        else
            printf '%ds' "$secs"
        fi
    }

    step_start() {
        local name=$1
        if $HAS_GUM; then
            gum style --foreground 212 --bold "◔ ${name}..."
        else
            echo "==> ${name}..."
        fi
    }

    step_done() {
        local name=$1 elapsed=$2
        if $HAS_GUM; then
            gum style --foreground 46 "● ${name} ($(format_time "$elapsed"))"
        else
            echo "==> ${name} done ($(format_time "$elapsed"))"
        fi
    }

    step_failed() {
        local name=$1 elapsed=$2
        if $HAS_GUM; then
            gum style --foreground 196 "◍ ${name} FAILED ($(format_time "$elapsed"))"
        else
            echo "==> ${name} FAILED ($(format_time "$elapsed"))"
        fi
    }

    run_step() {
        local name=$1; shift
        step_start "$name"
        local start=$SECONDS
        if "$@"; then
            step_done "$name" $((SECONDS - start))
        else
            step_failed "$name" $((SECONDS - start))
            echo ""
            if $HAS_GUM; then
                gum style --foreground 196 --border rounded --align center --padding "1 2" \
                    'BUILD FAILED' \
                    "Failed: ${name}" \
                    "Total elapsed: $(format_time $((SECONDS - OVERALL_START)))"
            else
                echo "BUILD FAILED: ${name}"
                echo "Total elapsed: $(format_time $((SECONDS - OVERALL_START)))"
            fi
            exit 1
        fi
    }

    # ── Banner ────────────────────────────────────────────────────
    if $HAS_GUM; then
        TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
        BANNER_WIDTH=$((TERM_WIDTH > 62 ? 60 : TERM_WIDTH - 4))
        gum style \
            --foreground 212 \
            --border-foreground 212 \
            --border double \
            --align center \
            --width $BANNER_WIDTH \
            --margin "1 2" \
            --padding "1 4" \
            'SHOW ME THE FUTURE' \
            'Building Bluefin from source and booting it in a VM'
    else
        echo ""
        echo "=== SHOW ME THE FUTURE ==="
        echo "Building Bluefin from source and booting it in a VM"
    fi
    echo ""

    # ── Steps ─────────────────────────────────────────────────────
    # Pinned to the `default` variant so we don't double the wall time
    # building the nvidia variant the user never boots in this flow.
    run_step "Build OCI image" just build default
    echo ""
    run_step "Bootable disk" just generate-bootable-image
    echo ""

    # Step 3: VM is interactive -- just announce it
    step_start "Launch VM"
    just boot-vm
    echo ""

    # ── Completion ────────────────────────────────────────────────
    if $HAS_GUM; then
        gum style --foreground 46 "● Launch VM"
        echo ""
        gum style \
            --foreground 46 \
            --border-foreground 46 \
            --border rounded \
            --align center \
            --width 42 \
            --padding "1 2" \
            'ALL STEPS COMPLETE' \
            "Total: $(format_time $((SECONDS - OVERALL_START)))"
    else
        echo "==> All steps complete. Total: $(format_time $((SECONDS - OVERALL_START)))"
    fi

# ── Chunkah ──────────────────────────────────────────────────────────
# Use the pre-built chunkah image from quay.io (v0.6.0).
# coreos/chunkah#113 is closed — the resolution is this physical overlay+xattr
# approach, not a libc fallback in chunkah. The overlay+fakecap-restore path
# remains required because chunkah's rustix xattr backend uses raw syscalls that
# bypass LD_PRELOAD, so xattrs must be physically applied to a writable overlay.
# See also: projectbluefin/dakota#231.
chunkify image_ref:
    #!/usr/bin/env bash
    set -euo pipefail

    if [ "${BUILD_SKIP_CHUNKIFY:-}" = "1" ]; then
        echo "==> Skipping chunkify (BUILD_SKIP_CHUNKIFY=1)"
        exit 0
    fi

    # Use sudo unless already root (CI runners are root)
    SUDO_CMD=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO_CMD="sudo"
    fi

    echo "==> Chunkifying {{image_ref}}..."

    # Get config from existing image
    CONFIG=$($SUDO_CMD podman inspect "{{image_ref}}")

    # Compile fakecap-restore from source if not already built.
    FAKECAP_RESTORE="{{justfile_directory()}}/files/fakecap/fakecap-restore"
    if [ ! -x "$FAKECAP_RESTORE" ]; then
        echo "==> Compiling fakecap-restore..."
        gcc -O2 -o "$FAKECAP_RESTORE" "{{justfile_directory()}}/files/fakecap/fakecap-restore.c"
    fi



    # Mount the image as a writable overlay so we can physically set
    # user.component xattrs.  chunkah uses rustix raw syscalls for xattr
    # reads (bypassing libc/LD_PRELOAD), so real xattrs must be present.
    # See coreos/chunkah#113.
    LOWER=$($SUDO_CMD podman image mount "{{image_ref}}")

    cleanup() {
        $SUDO_CMD umount "$MERGED" 2>/dev/null || true
        $SUDO_CMD rm -rf "$UPPER" "$WORK" "$MERGED"
        $SUDO_CMD podman image umount "{{image_ref}}" >/dev/null 2>&1 || true
    }
    trap cleanup EXIT

    # Pick the tmpdir with the most free space for the overlay work dirs.
    # fakecap-restore triggers overlayfs copy-up for every file it touches
    # (700K+ entries); copy-ups can exhaust /var/tmp on machines where root
    # has little free space (e.g. CI runners with a BTRFS loopback for
    # /var/lib/containers).  Mirror the same logic used in chunka@v1.
    _OVERLAY_TMPDIR="/var/tmp"
    for _candidate in /var/lib/containers /var/tmp; do
        if [ -d "$_candidate" ]; then
            _free=$(df --output=avail "$_candidate" 2>/dev/null | tail -1 || echo 0)
            _best=$(df --output=avail "$_OVERLAY_TMPDIR" 2>/dev/null | tail -1 || echo 0)
            if (( _free > _best )); then _OVERLAY_TMPDIR="$_candidate"; fi
        fi
    done
    echo "==> overlay tmpdir: ${_OVERLAY_TMPDIR} ($(df -h --output=avail "${_OVERLAY_TMPDIR}" | tail -1 | tr -d ' ') free)"
    UPPER=$(mktemp -d -p "$_OVERLAY_TMPDIR"); WORK=$(mktemp -d -p "$_OVERLAY_TMPDIR"); MERGED=$(mktemp -d -p "$_OVERLAY_TMPDIR")
    $SUDO_CMD chmod 755 "$UPPER" "$WORK" "$MERGED"
    $SUDO_CMD mount -t overlay overlay \
        -o "lowerdir=${LOWER},upperdir=${UPPER},workdir=${WORK}" \
        "$MERGED"

    echo "==> Applying user.component xattrs via fakecap-restore..."
    $SUDO_CMD "$FAKECAP_RESTORE" files/fakecap-manifest.tsv "$MERGED"

    # Run chunkah against the overlay (bind-mounted read-only).
    # --max-layers 120 balances layer granularity with registry storage space.
    # CHUNKAH_CONFIG_STR preserves OCI labels (containers.bootc=1).
    # chunkah image pinned by tag+digest for reproducibility.
    # Pre-pull with retries so transient registry 5xx errors don't abort the run.
    # Note: coreos/chunkah#113 was closed — the resolution is this overlay+xattr approach,
    # not a libc fallback in chunkah. The overlay+fakecap path stays required.
    CHUNKAH_REF="quay.io/coreos/chunkah:v0.6.0@sha256:ff8b8b466a942ec6000445d4001fc661e2fc5a952ad9ee29b4de9ab09d1d1708"
    for attempt in 1 2 3; do
        $SUDO_CMD podman pull "$CHUNKAH_REF" && break
        echo "==> chunkah pull attempt $attempt failed, retrying in 10s..."
        [ "$attempt" -lt 3 ] && sleep 10
    done
    LOADED=$($SUDO_CMD podman run --rm \
        --pull never \
        --security-opt label=type:unconfined_t \
        -v "${MERGED}:/chunkah:ro" \
        -e "CHUNKAH_ROOTFS=/chunkah" \
        -e "CHUNKAH_CONFIG_STR=$CONFIG" \
        "$CHUNKAH_REF" build --max-layers 120 --prune /sysroot/ \
        --label ostree.commit- --label ostree.final-diffid- \
        | $SUDO_CMD podman load)

    echo "$LOADED"

    # Parse the loaded image reference. Handles all podman output formats:
    #   "Loaded image: <ref>"     — podman ≥4 with tagged OCI archive
    #   "Loaded image(s): <ref>"  — older podman
    #   bare 64-char hex sha256   — Ubuntu 24.04 podman for untagged archives
    NEW_REF=$(echo "$LOADED" | sed -n 's/^Loaded image(s): //p; s/^Loaded image: //p' | head -1)
    if [ -z "$NEW_REF" ]; then
        NEW_REF=$(echo "$LOADED" | grep -oP '^[0-9a-f]{64}$' | head -1 || true)
    fi

    if [ -n "$NEW_REF" ] && [ "$NEW_REF" != "{{image_ref}}" ]; then
        echo "==> Retagging chunked image to {{image_ref}}..."
        $SUDO_CMD podman tag "$NEW_REF" "{{image_ref}}"
    fi

    # Publish steps run as the unprivileged runner user after rootful chunkah.
    # Copy the result into that user's podman store before returning.
    if [ -n "$SUDO_CMD" ]; then
        $SUDO_CMD podman save "{{image_ref}}" | podman load
    fi

# ── bcvk (fast VM testing) ───────────────────────────────────────────

# Ensure bcvk is installed (auto-installs via cargo if missing)
_ensure-bcvk:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v bcvk &>/dev/null; then
        exit 0
    fi
    echo "bcvk not found. Attempting to install via cargo..."
    if command -v cargo &>/dev/null; then
        cargo install --locked --git https://github.com/bootc-dev/bcvk bcvk
    else
        echo "ERROR: bcvk is not installed and cargo is not available for auto-install." >&2
        echo "" >&2
        echo "Install bcvk manually:" >&2
        echo "  Cargo:       cargo install --locked --git https://github.com/bootc-dev/bcvk bcvk" >&2
        echo "  Fedora 42+:  sudo dnf install bcvk" >&2
        echo "" >&2
        echo "Also ensure qemu-kvm and virtiofsd are installed on the host." >&2
        exit 1
    fi

# Boot the built image instantly in an ephemeral VM via bcvk.
# No disk image needed -- boots directly from the container via virtiofs.
# Requires: bcvk, qemu-kvm, virtiofsd (sudo dnf install bcvk qemu-kvm virtiofsd)
[group('test')]
boot-fast: _ensure-bcvk
    #!/usr/bin/env bash
    set -euo pipefail

    # Use sudo unless already root
    SUDO_CMD=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO_CMD="sudo"
    fi

    if ! $SUDO_CMD podman image exists "{{image_name}}:{{image_tag}}"; then
        echo "ERROR: Image '{{image_name}}:{{image_tag}}' not found in podman." >&2
        echo "Run 'just build' first to build and export the OCI image." >&2
        exit 1
    fi

    echo "==> Booting {{image_name}}:{{image_tag}} in ephemeral VM (bcvk)..."
    echo "    RAM: {{vm_ram}}M, CPUs: {{vm_cpus}}"
    echo "    No disk image -- boots directly via virtiofs"
    echo ""
    $SUDO_CMD bcvk ephemeral run-ssh \
        --memory "{{vm_ram}}M" \
        --vcpus "{{vm_cpus}}" \
        "localhost/{{image_name}}:{{image_tag}}"

# Interactive debug session — boots the image, captures serial console and systemd
# journal on exit. Artifacts are saved to ./debug-session/ for bug reports.
# Requires: bcvk, qemu-kvm, virtiofsd
[group('test')]
debug-session: _ensure-bcvk
    #!/usr/bin/env bash
    set -euo pipefail

    VM_NAME="dakota-debug-$$"
    SESSION_DIR="./debug-session"
    START_TS=$(date +%s)

    # Use sudo unless already root
    SUDO_CMD=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO_CMD="sudo"
    fi

    if ! $SUDO_CMD podman image exists "{{image_name}}:{{image_tag}}"; then
        echo "ERROR: Image '{{image_name}}:{{image_tag}}' not found in podman." >&2
        echo "Run 'just build' first to build and export the OCI image." >&2
        exit 1
    fi

    cleanup() {
        set +e
        END_TS=$(date +%s)
        DURATION=$((END_TS - START_TS))

        # Capture console log via podman logs (works even if guest hung/crashed)
        $SUDO_CMD podman logs "$VM_NAME" > "${SESSION_DIR}/serial.log" 2>/dev/null || true

        # Capture journal and summary via SSH if VM is still reachable
        KERNEL="unknown"
        FAILED_DISPLAY="none"
        if $SUDO_CMD bcvk ephemeral ssh "$VM_NAME" -- true 2>/dev/null; then
            echo "==> Capturing systemd journal..."
            $SUDO_CMD bcvk ephemeral ssh "$VM_NAME" -- journalctl -b --no-pager > "${SESSION_DIR}/journal.log" 2>/dev/null || true

            KERNEL=$($SUDO_CMD bcvk ephemeral ssh "$VM_NAME" -- uname -r 2>/dev/null || echo "unknown")
            FAILED=$($SUDO_CMD bcvk ephemeral ssh "$VM_NAME" -- systemctl list-units --state=failed --no-legend --plain 2>/dev/null | awk '{print $1}' | head -10 | paste -sd ',' 2>/dev/null || true)
            if [ -n "$FAILED" ]; then FAILED_DISPLAY="$FAILED"; fi
        fi

        {
            echo "Debug session: {{image_name}}:{{image_tag}}"
            echo "Duration: ${DURATION}s"
            echo "Kernel: ${KERNEL}"
            echo "Failed units: ${FAILED_DISPLAY}"
            echo ""
            echo "Artifacts:"
            echo "  serial.log   — full serial console from boot"
            echo "  journal.log  — systemd journal from this boot"
            echo "  summary.txt  — this file"
            echo ""
            echo "Include these artifacts when filing an issue at:"
            echo "  https://github.com/projectbluefin/dakota/issues/new?template=bug-report.yml"
        } > "${SESSION_DIR}/summary.txt"

        echo ""
        echo "==> Debug session artifacts in ${SESSION_DIR}/"
        if [[ -f "${SESSION_DIR}/serial.log" ]]; then
            echo "    serial.log   ($(du -sh "${SESSION_DIR}/serial.log" | cut -f1)) — full serial console from boot"
        fi
        if [[ -f "${SESSION_DIR}/journal.log" ]]; then
            echo "    journal.log  ($(du -sh "${SESSION_DIR}/journal.log" | cut -f1)) — systemd journal from this boot"
        fi
        if [[ -f "${SESSION_DIR}/summary.txt" ]]; then
            echo "    summary.txt  — session summary"
        fi
        echo ""
        echo "File an issue with the artifacts above:"
        echo "  https://github.com/projectbluefin/dakota/issues/new?template=bug-report.yml"

        echo "==> Tearing down VM ${VM_NAME}..."
        $SUDO_CMD bcvk ephemeral rm -f "$VM_NAME" 2>/dev/null || true
    }
    trap cleanup EXIT

    mkdir -p "${SESSION_DIR}"

    echo "==> debug-session: booting {{image_name}}:{{image_tag}} with serial capture..."
    echo "    RAM: {{vm_ram}}M, CPUs: {{vm_cpus}}"
    echo "    Artifacts will be saved to ${SESSION_DIR}/"
    echo ""

    # Launch VM detached; -K enables bcvk ephemeral ssh, --console routes guest
    # serial output to podman logs for reliable capture even when guest is hung
    $SUDO_CMD bcvk ephemeral run -d --rm -K --console \
        --memory "{{vm_ram}}M" \
        --vcpus "{{vm_cpus}}" \
        --name "$VM_NAME" \
        "localhost/{{image_name}}:{{image_tag}}"

    # Wait for SSH to become available
    echo "==> Waiting for VM to boot..."
    ELAPSED=0
    TIMEOUT=120
    while [ $ELAPSED -lt "$TIMEOUT" ]; do
        if $SUDO_CMD bcvk ephemeral ssh "$VM_NAME" -- true 2>/dev/null; then
            break
        fi
        sleep 5
        ELAPSED=$((ELAPSED + 5))
        printf '.' >&2
    done
    echo ""

    if [ $ELAPSED -ge "$TIMEOUT" ]; then
        echo "FAIL: SSH did not become available within ${TIMEOUT}s" >&2
        exit 1
    fi
    echo "==> VM ready after ~${ELAPSED}s. Starting interactive session."
    echo "    Reproduce your bug here. Exit the shell when done (Ctrl+D)."
    echo ""

    # Drop user into interactive SSH session
    $SUDO_CMD bcvk ephemeral ssh "$VM_NAME"

# Automated boot smoke test — boots the image, verifies GDM starts, exits 0/1.
# Non-interactive. Intended for CI and agent verification loops.
# Requires: bcvk, qemu-kvm, virtiofsd
[group('test')]
boot-test: _ensure-bcvk
    #!/usr/bin/env bash
    set -euo pipefail

    VM_NAME="dakota-boot-test-$$"
    TIMEOUT="${BOOT_TEST_TIMEOUT:-120}"
    STATUS=1

    # Use sudo unless already root
    SUDO_CMD=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO_CMD="sudo"
    fi

    if ! $SUDO_CMD podman image exists "{{image_name}}:{{image_tag}}"; then
        echo "ERROR: Image '{{image_name}}:{{image_tag}}' not found in podman." >&2
        echo "Run 'just build' first to build and export the OCI image." >&2
        exit 1
    fi

    cleanup() {
        echo "==> Tearing down VM ${VM_NAME}..."
        $SUDO_CMD bcvk ephemeral rm -f "$VM_NAME" 2>/dev/null || true
    }
    trap cleanup EXIT

    echo "==> boot-test: launching ephemeral VM (timeout: ${TIMEOUT}s)..."
    $SUDO_CMD bcvk ephemeral run -d --rm -K \
        --memory "{{vm_ram}}M" \
        --vcpus "{{vm_cpus}}" \
        --name "$VM_NAME" \
        "localhost/{{image_name}}:{{image_tag}}"

    # Wait for SSH to become available
    echo "==> Waiting for SSH..."
    ELAPSED=0
    while [ $ELAPSED -lt "$TIMEOUT" ]; do
        if $SUDO_CMD bcvk ephemeral ssh "$VM_NAME" -- true 2>/dev/null; then
            break
        fi
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    done

    if [ $ELAPSED -ge "$TIMEOUT" ]; then
        echo "FAIL: SSH did not become available within ${TIMEOUT}s" >&2
        exit 1
    fi
    echo "==> SSH up after ~${ELAPSED}s"

    # Check services
    echo "==> Checking critical services..."
    CHECKS=(
        "graphical.target:systemctl is-active graphical.target"
        "gdm:systemctl is-active gdm"
        "bootc:bootc status"
        "no-zram:test ! -e /sys/block/zram0"
    )

    PASS=0
    FAIL=0
    for check in "${CHECKS[@]}"; do
        NAME="${check%%:*}"
        CMD="${check#*:}"
        if $SUDO_CMD bcvk ephemeral ssh "$VM_NAME" -- $CMD &>/dev/null; then
            echo "  ✓ ${NAME}"
            PASS=$((PASS + 1))
        else
            echo "  ✗ ${NAME}" >&2
            FAIL=$((FAIL + 1))
        fi
    done

    echo ""
    if [ $FAIL -eq 0 ]; then
        echo "PASS: all ${PASS} checks passed"
        STATUS=0
    else
        echo "FAIL: ${FAIL} check(s) failed" >&2
    fi
    exit $STATUS

# Inspect the built bootc image.
[group('info')]
inspect: _ensure-bcvk
    #!/usr/bin/env bash
    set -euo pipefail

    # Use sudo unless already root
    SUDO_CMD=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO_CMD="sudo"
    fi

    $SUDO_CMD bcvk images list

# ── SBOM ─────────────────────────────────────────────────────────────
# Generate a BST-native SBOM (SPDX 2.3) using buildstream-sbom.
# Reads directly from BST element metadata — captures all ~1100+ elements
# including GNOME/GTK/systemd from junctions (unlike syft which can only
# fingerprint binaries in the rootfs and misses source-built packages).
# Does NOT require a pre-built image — just the BST project files.
# Output: dakota.spdx.json in repo root.
#
# Local testing:
#   just sbom                                # generate SBOM
#   jq '.spdxVersion' dakota.spdx.json      # verify SPDX-2.3
#   jq '.packages | length' dakota.spdx.json  # expect ~1100+
#   jq -r '.packages[].name' dakota.spdx.json | grep -i "gnome\|gtk\|systemd"
[group('test')]
sbom variant="default":
    #!/usr/bin/env bash
    set -euo pipefail

    case "{{variant}}" in
        default) ELEMENT="oci/bluefin.bst";        SPDX_NAME="dakota";        OUTFILE="dakota.spdx.json" ;;
        nvidia)  ELEMENT="oci/bluefin-nvidia.bst"; SPDX_NAME="dakota-nvidia"; OUTFILE="dakota-nvidia.spdx.json" ;;
        *) echo "ERROR: unknown variant '{{variant}}' (expected: default | nvidia)" >&2; exit 1 ;;
    esac

    # Persist host-side caches before bind-mounting them into podman.
    # actions/cache restores archives but does not create missing directories on a cold miss.
    mkdir -p "${HOME}/.cache/buildstream"
    mkdir -p "${HOME}/.config/buildstream-generate"
    GIT_SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
    # Prime the generated source plugin cache (snakeoil secureboot keys).
    # The gnome-build-meta generated.py plugin runs `make` on first use and
    # caches the result. If the cache is cold, the make output pollutes stdout
    # and breaks buildstream-sbom's bst show pipe. Priming here ensures the
    # cache is warm before buildstream-sbom runs.
    echo "==> Priming BST generated source cache (${ELEMENT})..."
    podman run --rm \
        --network=host \
        --runtime runc \
        -v "{{justfile_directory()}}:/src:rw" \
        -v "${HOME}/.cache/buildstream:/root/.cache/buildstream:rw" \
        -v "${HOME}/.config/buildstream-generate:/root/.config/buildstream-generate:rw" \
        -w /src \
        "{{bst2_image}}" \
        bash -c "bst --no-colors show --deps none --format '%{name}' ${ELEMENT}" \
        2>/dev/null || true

    echo "==> Generating BST-native SBOM with buildstream-sbom (${ELEMENT} → ${OUTFILE})..."
    # Ensure pip cache directory exists before podman bind-mount.
    # actions/cache does not create the path on a cold cache miss; podman
    # refuses to start (exit 125) if the host-side directory is absent.
    mkdir -p "${HOME}/.cache/pip"
    # Pinned to commit 0706fec3 (2026-04-01) — latest main, includes element
    # names in SPDX output (issue #9 fix). Switch to a versioned PyPI release
    # once the project publishes one.
    podman run --rm \
        --network=host \
        --runtime runc \
        -v "{{justfile_directory()}}:/src:rw" \
        -v "${HOME}/.cache/buildstream:/root/.cache/buildstream:rw" \
        -v "${HOME}/.config/buildstream-generate:/root/.config/buildstream-generate:rw" \
        -v "${HOME}/.cache/pip:/root/.cache/pip:rw" \
        -w /src \
        -e ELEMENT="${ELEMENT}" \
        -e SPDX_NAME="${SPDX_NAME}" \
        -e OUTFILE="${OUTFILE}" \
        -e GIT_SHA="${GIT_SHA}" \
        "{{bst2_image}}" \
        bash -c '
            for attempt in 1 2 3; do
                pip install --quiet \
                    git+https://gitlab.com/BuildStream/buildstream-sbom.git@0706fec3bedf6f73bd9d2fed32c2aed585feef8d \
                    && break
                echo "buildstream-sbom install failed (attempt ${attempt}/3); retrying in 5s..."
                [ "${attempt}" -lt 3 ] && sleep 5
            done
            buildstream-sbom "${ELEMENT}" \
                --spdx-name "${SPDX_NAME}" \
                --spdx-namespace "https://github.com/projectbluefin/dakota/sbom/${GIT_SHA}" \
                --spdx-creator "Tool: buildstream-sbom" \
                --spdx-creator "Organization: projectbluefin" \
                --deps all \
                --output "/src/${OUTFILE}"
        '
    echo ""
    echo "==> SBOM written to: $(pwd)/${OUTFILE}"
    du -sh "${OUTFILE}"
    echo ""
    echo "==> Package count:"
    jq '.packages | length' "${OUTFILE}"

# ── Verify supply-chain signatures ───────────────────────────────────
# Verify cosign signature + SBOM referrer + SLSA attestation for a
# pushed image. Requires: cosign, oras, gh CLI.
# Usage: just verify                           (uses IMAGE_REGISTRY/IMAGE_NAME:latest)
#        just verify ghcr.io/projectbluefin/dakota:latest
[group('test')]
verify image_ref="":
    #!/usr/bin/env bash
    set -euo pipefail

    IMAGE="{{image_ref}}"
    [ -z "$IMAGE" ] && IMAGE="ghcr.io/projectbluefin/dakota:latest"

    echo "==> Verifying supply-chain security for: ${IMAGE}"
    echo ""
    STATUS=0

    # 1. Cosign keyless signature
    echo "── Cosign signature (keyless / Sigstore OIDC) ──"
    if ! command -v cosign &>/dev/null; then
        echo "SKIP: cosign not installed"
    else
        cosign verify \
            --certificate-identity-regexp \
                '^https://github\.com/projectbluefin/dakota/\.github/workflows/publish\.yml@refs/heads/(main|gh-readonly-queue/main/.+)$' \
            --certificate-oidc-issuer https://token.actions.githubusercontent.com \
            "${IMAGE}" && echo "PASS: signature valid" || { echo "FAIL: signature check failed"; STATUS=1; }
    fi
    echo ""

    # 2. SBOM referrer
    echo "── SBOM OCI referrer ──"
    if ! command -v oras &>/dev/null; then
        echo "SKIP: oras not installed"
    else
        oras discover "${IMAGE}" && echo "PASS: referrers listed above" || { echo "FAIL: oras discover failed"; STATUS=1; }
    fi
    echo ""

    # 3. SLSA attestation
    echo "── SLSA build provenance (actions/attest) ──"
    if ! command -v gh &>/dev/null; then
        echo "SKIP: gh not installed"
    else
        gh attestation verify "oci://${IMAGE}" \
            --repo projectbluefin/dakota && echo "PASS: attestation valid" || { echo "FAIL: attestation check failed"; STATUS=1; }
    fi
    exit "${STATUS}"

# ── E2E dispatch ─────────────────────────────────────────────────────
# e2e.yml is workflow_dispatch-only — PRs do not publish a :testing build
# first, so running smoke on a PR would test a stale image. Dispatching it was
# a loose `gh workflow run` incantation with no recipe until now.
#
# Dispatch the e2e workflow against a published image.
[group('test')]
e2e suites="smoke" image="ghcr.io/projectbluefin/dakota:testing":
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v gh >/dev/null 2>&1; then
        echo "gh CLI is required to dispatch the e2e workflow" >&2
        exit 2
    fi
    echo "==> Dispatching e2e: suites={{suites}} image={{image}}"
    gh workflow run e2e.yml \
        --repo projectbluefin/dakota \
        --field image="{{image}}" \
        --field suites="{{suites}}"
    echo "==> Watch it with: gh run list --repo projectbluefin/dakota --workflow e2e.yml --limit 5"

# Only meaningful against a fisherman to-filesystem install — see the header
# of .github/workflows/e2e.yml for which of the three assertions gate on what.
# Usage: just e2e-installer ghcr.io/projectbluefin/dakota:testing
#
# Dispatch the fisherman post-boot assertions (projectbluefin/dakota#651).
[group('test')]
e2e-installer image="ghcr.io/projectbluefin/dakota:testing":
    just e2e installer "{{image}}"

# ── Lint ─────────────────────────────────────────────────────────────
[group('test')]
lint:
    #!/usr/bin/env bash
    set -euo pipefail

    # Use sudo unless already root
    SUDO_CMD=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO_CMD="sudo"
    fi

    echo "==> Linting {{image_name}}:{{image_tag}} with bootc container lint..."
    $SUDO_CMD podman run --rm --privileged --pull=never \
        "{{image_name}}:{{image_tag}}" \
        bootc container lint

# ── Swap audit ───────────────────────────────────────────────────────
# Assert the image's swap architecture: zram disabled, zswap kargs present,
# swapfile units wired. Guards against the #1131 overlap regression where the
# upstream zram-generator config silently won over the intended override.
[group('test')]
swap-audit:
    #!/usr/bin/env bash
    set -euo pipefail

    # Use sudo unless already root
    SUDO_CMD=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO_CMD="sudo"
    fi

    echo "==> Auditing swap/zram configuration in {{image_name}}:{{image_tag}}..."
    $SUDO_CMD podman run --rm --pull=never \
        "{{image_name}}:{{image_tag}}" \
        bash -c '
        set -uo pipefail
        STATUS=0
        fail() { echo "FAIL: $1" >&2; STATUS=1; }

        if grep -q "^\[zram" /usr/lib/systemd/zram-generator.conf 2>/dev/null; then
            fail "/usr/lib/systemd/zram-generator.conf still defines a zram device"
        fi
        if compgen -G "/etc/systemd/zram-generator.conf*" > /dev/null; then
            fail "unexpected zram-generator config under /etc"
        fi

        KARGS=/usr/lib/bootc/kargs.d/20-zswap.toml
        if [ ! -f "$KARGS" ]; then
            fail "$KARGS missing"
        else
            grep -q "zswap.enabled=1" "$KARGS" || fail "zswap.enabled=1 karg missing"
            # kernel 7.x removed the zswap.zpool parameter
            grep -q "zpool" "$KARGS" && fail "dead zswap.zpool karg present"
        fi

        [ -f /usr/lib/systemd/system/var-swap-swapfile.swap ] \
            || fail "var-swap-swapfile.swap unit missing"
        [ -L /usr/lib/systemd/system/swap.target.wants/var-swap-swapfile.swap ] \
            || fail "swap.target.wants/var-swap-swapfile.swap symlink missing"
        [ -x /usr/libexec/bluefin-swapfile-init ] \
            || fail "/usr/libexec/bluefin-swapfile-init missing or not executable"

        # Actually run it. The container overlayfs cannot back a swapfile so it
        # exits early, but only after sizing and the free-space arithmetic --
        # which is where a broken coreutils invocation would surface. Presence
        # checks alone shipped exactly such a bug once.
        /usr/libexec/bluefin-swapfile-init \
            || fail "bluefin-swapfile-init exited non-zero"

        [ "$STATUS" -eq 0 ] && echo "PASS: swap/zram configuration OK"
        exit "$STATUS"
        '

# ── Avatar audit ─────────────────────────────────────────────────────
# Assert the Bluefin dinosaur avatars are actually reachable by GNOME's
# account-picture pickers. Guards against the #353 regression class, where
# the art shipped fine but nothing pointed GNOME at it.
#
# Two independent ways this breaks silently, both checked here:
#   1. common.bst stops ingesting /usr/share/pixmaps/faces/bluefin/*.jpg.
#   2. The dconf override ships but never reaches the compiled distro db
#      (element dropped from the layer, or `dconf update` did not run).
#
# org.gnome.desktop.interface avatar-directories REPLACES the default face
# dirs rather than adding to them (gnome-control-center
# panels/system/users/cc-avatar-chooser.c, gnome-initial-setup
# pages/account/um-photo-dialog.c), so a stale or typo'd path yields an
# empty picker with no fallback. Every listed dir is therefore checked for
# existence and for actual .jpg content.
[group('test')]
avatar-audit:
    #!/usr/bin/env bash
    set -euo pipefail

    # Use sudo unless already root
    SUDO_CMD=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO_CMD="sudo"
    fi

    echo "==> Auditing user-avatar configuration in {{image_name}}:{{image_tag}}..."
    $SUDO_CMD podman run --rm --pull=never \
        "{{image_name}}:{{image_tag}}" \
        bash -c '
        set -uo pipefail
        STATUS=0
        fail() { echo "FAIL: $1" >&2; STATUS=1; }

        Q=$(printf "\047")
        KEYFILE=/etc/dconf/db/distro.d/07-dakota-avatar-directories
        DB=/etc/dconf/db/distro

        # The art itself, straight from bluefin/common.bst.
        compgen -G "/usr/share/pixmaps/faces/bluefin/*.jpg" > /dev/null \
            || fail "no Bluefin avatar art under /usr/share/pixmaps/faces/bluefin"

        # The distro dconf profile must read the distro db at all.
        grep -qx "system-db:distro" /etc/dconf/profile/user 2>/dev/null \
            || fail "/etc/dconf/profile/user does not read system-db:distro"

        if [ ! -f "$KEYFILE" ]; then
            fail "$KEYFILE missing"
        elif [ ! -f "$DB" ]; then
            fail "compiled dconf db $DB missing -- did dconf update run?"
        else
            VALUE=$(sed -n "s/^avatar-directories=//p" "$KEYFILE")
            if [ -z "$VALUE" ]; then
                fail "avatar-directories key missing from $KEYFILE"
            else
                DIRS=$(printf "%s" "$VALUE" | tr -d "[]${Q} " | tr "," "\n" | grep -v "^$")
                if [ -z "$DIRS" ]; then
                    fail "avatar-directories is empty -- the picker would show nothing"
                else
                    while read -r dir; do
                        [ -d "$dir" ] \
                            || { fail "avatar-directories lists $dir, which is not in the image"; continue; }
                        compgen -G "${dir}/*.jpg" > /dev/null \
                            || fail "$dir contains no .jpg faces"
                        # gvdb keeps strings verbatim, so the compiled db can
                        # be grepped without a dconf/D-Bus round trip.
                        grep -qaF "$dir" "$DB" \
                            || fail "$dir absent from compiled $DB -- override did not reach the db"
                    done <<< "$DIRS"
                fi
            fi
        fi

        [ "$STATUS" -eq 0 ] && echo "PASS: user-avatar configuration OK"
        exit "$STATUS"
        '
