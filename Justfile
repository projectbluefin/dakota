# List available commands
[group('info')]
default:
    @just --list

# ── Configuration ─────────────────────────────────────────────────────
export image_name := env("BUILD_IMAGE_NAME", "dakota")
export image_tag := env("BUILD_IMAGE_TAG", "latest")
export base_dir := env("BUILD_BASE_DIR", ".")
export filesystem := env("BUILD_FILESYSTEM", "btrfs")

# Same bst2 container image CI uses -- pinned by SHA for reproducibility
export bst2_image := env("BST2_IMAGE", "registry.gitlab.com/freedesktop-sdk/infrastructure/freedesktop-sdk-docker-images/bst2:64eb0b4930d57a92710822898fb73af6cc1ae35d")

# VM settings
export vm_ram := env("VM_RAM", "8192")
export vm_cpus := env("VM_CPUS", "4")

# OCI metadata (dynamic labels)
export OCI_IMAGE_CREATED := env("OCI_IMAGE_CREATED", "")
export OCI_IMAGE_REVISION := env("OCI_IMAGE_REVISION", "")
export OCI_IMAGE_VERSION := env("OCI_IMAGE_VERSION", "latest")

# ── BuildStream wrapper ──────────────────────────────────────────────
# Runs any bst command inside the bst2 container via podman.
# Defaults to `-o x86_64_v3 true --no-interactive` so local runs match CI.
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
    DEFAULT_BST_FLAGS="-o x86_64_v3 true --no-interactive"
    if [ -n "${BST_FLAGS_OVERRIDE:-}" ]; then
        EFFECTIVE_BST_FLAGS="${BST_FLAGS_OVERRIDE}"
    else
        EFFECTIVE_BST_FLAGS="${BST_FLAGS:-}"
        if [[ ! " ${EFFECTIVE_BST_FLAGS} " =~ [[:space:]]-o[[:space:]]+x86_64_v3[[:space:]]+true([[:space:]]|$) ]]; then
            EFFECTIVE_BST_FLAGS="${DEFAULT_BST_FLAGS} ${EFFECTIVE_BST_FLAGS}"
        fi
        if [[ ! " ${EFFECTIVE_BST_FLAGS} " =~ [[:space:]]--no-interactive([[:space:]]|$) ]]; then
            EFFECTIVE_BST_FLAGS="${EFFECTIVE_BST_FLAGS} --no-interactive"
        fi
    fi

    # BST_FLAGS allows appending --no-interactive, --config, etc.
    # Word-splitting is intentional here (flags are space-separated).
    # shellcheck disable=SC2086
    podman run --rm \
        --privileged \
        --device /dev/fuse \
        --network=host \
        -v "{{justfile_directory()}}:/src:rw" \
        -v "${HOME}/.cache/buildstream:/root/.cache/buildstream:rw" \
        -w /src \
        "{{bst2_image}}" \
        bash -c 'bst --colors "$@"' -- ${EFFECTIVE_BST_FLAGS} {{ARGS}}

# Validate BST element graph — mirrors CI validate job.
[group('dev')]
validate:
    just bst show --deps all oci/bluefin.bst
    just bst show --deps all oci/bluefin-nvidia.bst

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
    # shellcheck disable=SC2086
    printf 'FROM %s\nRUN sed -i "s/^VERSION_ID=.*/VERSION_ID=\\"%s\\"/" /usr/lib/os-release \\\n    && sed -i "s/^IMAGE_VERSION=.*/IMAGE_VERSION=\\"%s\\"/" /usr/lib/os-release\n' "$IMAGE_ID" "$DATE_TAG" "$DATE_TAG" \
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

    UPPER=$(mktemp -d -p /var/tmp); WORK=$(mktemp -d -p /var/tmp); MERGED=$(mktemp -d -p /var/tmp)
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

    # Persist the snakeoil key cache so bst show runs silently (see bst recipe).
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
