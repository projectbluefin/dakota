kind: manual
description: |
  NVIDIA proprietary driver: userspace + open kernel modules, both built
  from the .run installer's bundled kernel-open/ tree (the path NVIDIA's
  release engineering validates).

  Hardware: Turing+ only (GTX 16xx, RTX 20xx-50xx, datacenter A/H/L/B).
  Pascal and earlier need the closed-source kernel module we don't ship.

  To bump version: change url, ref (sha256), filename, and nvidia-version
  below. Latest at https://www.nvidia.com/en-us/drivers/unix/.

build-depends:
- freedesktop-sdk.bst:bootstrap/coreutils.bst
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/sed.bst
- freedesktop-sdk.bst:components/gcc-base.bst
- freedesktop-sdk.bst:bootstrap/binutils.bst
- freedesktop-sdk.bst:components/make.bst
- freedesktop-sdk.bst:components/gawk.bst
- freedesktop-sdk.bst:components/findutils.bst
- freedesktop-sdk.bst:components/linux.bst
# Kernel's objtool is dynamically linked against libxxhash.so.0; without
# this the module link fails with "libxxhash.so.0: not found".
- freedesktop-sdk.bst:components/xxhash.bst
# Tools makeself shells out to during self-extraction.
- freedesktop-sdk.bst:components/grep.bst
- freedesktop-sdk.bst:components/tar.bst
- freedesktop-sdk.bst:components/gzip.bst
- freedesktop-sdk.bst:components/xz.bst
- freedesktop-sdk.bst:components/zstd.bst
- freedesktop-sdk.bst:components/cpio.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
# linux.bst is intentionally NOT a runtime-depend: gnomeos provides
# the kernel via gnomeos/initramfs/signed-modules.bst, and pulling
# linux.bst at runtime stages /boot/vmlinuz into compose sandboxes,
# clashing with gnomeos/stack.bst's `mkdir /boot` integration command.

sources:
- kind: remote
  url: nvidia:XFree86/Linux-x86_64/610.43.02/NVIDIA-Linux-x86_64-610.43.02.run
  ref: 3034a054bb4cdf7752ff8dc272564cb105513804bff53538945901b16ca77463
  filename: NVIDIA-Linux-x86_64-610.43.02.run

variables:
  nvidia-version: '610.43.02'
  strip-binaries: ''

config:
  build-commands:
  - |
    # NOT using `set -e -o pipefail`: the makeself extraction below pipes
    # `tail | xz -dc | tar`, and tail SIGPIPEs once tar finishes — under
    # pipefail that propagates as exit 143 and masks any real error.
    set -u
    chmod +x NVIDIA-Linux-x86_64-%{nvidia-version}.run
    # Bypass NVIDIA's makeself wrapper (it does curses prompting that
    # SIGTERMs itself under BST's no-tty sandbox). The .run is just a
    # shell prologue + compressed tarball; we extract the payload directly.
    SKIP=$(grep -a -m1 -n '^skip=' NVIDIA-Linux-x86_64-%{nvidia-version}.run | head -1 | cut -d: -f1)
    if [ -z "$SKIP" ]; then
        echo "FATAL: couldn't locate makeself skip marker in .run" >&2
        exit 1
    fi
    PAYLOAD_LINE=$(grep -a -m1 '^skip=' NVIDIA-Linux-x86_64-%{nvidia-version}.run | sed 's/skip=//')
    PAYLOAD_HEAD=$(tail -n +$PAYLOAD_LINE NVIDIA-Linux-x86_64-%{nvidia-version}.run | head -c 6 | od -A n -t x1 | tr -d ' \n')
    case "$PAYLOAD_HEAD" in
        28b52ffd*)         DECOMPRESS="zstd -dc" ;;
        fd377a585a00*)     DECOMPRESS="xz -dc" ;;
        1f8b*)             DECOMPRESS="gzip -dc" ;;
        425a68*)           DECOMPRESS="bzip2 -dc" ;;
        *)
            echo "FATAL: unknown payload magic 0x$PAYLOAD_HEAD" >&2
            exit 1
            ;;
    esac
    echo "Payload starts at line $PAYLOAD_LINE, decompressor=$DECOMPRESS"
    mkdir -p extracted
    # --no-same-owner / --no-same-permissions: BST sandbox can't chown
    # or preserve setuid bits as a non-root uid.
    tail -n +$PAYLOAD_LINE NVIDIA-Linux-x86_64-%{nvidia-version}.run \
        | $DECOMPRESS \
        | tar -xf - -C extracted --no-same-owner --no-same-permissions
    if [ ! -d extracted ] || [ -z "$(ls -A extracted 2>/dev/null)" ]; then
        echo "FATAL: extraction produced empty directory" >&2
        exit 1
    fi
    echo "Extracted $(ls extracted | wc -l) top-level entries"
  - |
    set -euo pipefail
    KVER=$(ls /usr/lib/modules | head -n1)
    if [ -z "$KVER" ] || [ ! -d "/usr/lib/modules/$KVER/build" ]; then
        echo "FATAL: no kernel build tree found under /usr/lib/modules" >&2
        exit 1
    fi
    cd extracted/kernel-open
    # GCC 14+ (FDSDK 25.08) makes -Wincompatible-pointer-types a hard
    # error; NVIDIA's source still has benign mismatches. Demote to warn.
    echo 'EXTRA_CFLAGS += -Wno-error=incompatible-pointer-types' >> Kbuild
    echo "Building NVIDIA kernel modules against $KVER"
    make -j${BST_BUILD_THREADS:-1} KERNEL_UNAME="$KVER"

  install-commands:
  # depmod is intentionally deferred to OCI integration time so it sees
  # the composed root, not just nvidia-drivers' install root.
  - |
    set -euo pipefail
    KVER=$(ls /usr/lib/modules | head -n1)
    cd extracted/kernel-open
    make -j1 KERNEL_UNAME="$KVER" modules_install \
        INSTALL_MOD_PATH="%{install-root}/usr"
    cd ../..
  - |
    set -euo pipefail
    cd extracted
    LIBDIR="%{install-root}%{libdir}"
    install -d "$LIBDIR" "$LIBDIR/vdpau"

    for lib in \
        libcuda.so.%{nvidia-version} \
        libnvcuvid.so.%{nvidia-version} \
        libnvidia-allocator.so.%{nvidia-version} \
        libnvidia-cfg.so.%{nvidia-version} \
        libnvidia-eglcore.so.%{nvidia-version} \
        libnvidia-encode.so.%{nvidia-version} \
        libnvidia-fbc.so.%{nvidia-version} \
        libnvidia-glcore.so.%{nvidia-version} \
        libnvidia-glsi.so.%{nvidia-version} \
        libnvidia-glvkspirv.so.%{nvidia-version} \
        libnvidia-ml.so.%{nvidia-version} \
        libnvidia-opticalflow.so.%{nvidia-version} \
        libnvidia-ptxjitcompiler.so.%{nvidia-version} \
        libnvidia-rtcore.so.%{nvidia-version} \
        libnvidia-tls.so.%{nvidia-version} \
        libnvoptix.so.%{nvidia-version} \
        libEGL_nvidia.so.%{nvidia-version} \
        libGLESv1_CM_nvidia.so.%{nvidia-version} \
        libGLESv2_nvidia.so.%{nvidia-version} \
        libGLX_nvidia.so.%{nvidia-version} \
        libnvidia-opencl.so.%{nvidia-version} \
    ; do
        if [ -f "$lib" ]; then
            install -Dm755 "$lib" "$LIBDIR/$lib"
        fi
    done

    # VDPAU GPU driver goes in the vdpau/ sub-directory, not $LIBDIR root.
    if [ -f "libvdpau_nvidia.so.%{nvidia-version}" ]; then
        install -Dm755 "libvdpau_nvidia.so.%{nvidia-version}" \
            "$LIBDIR/vdpau/libvdpau_nvidia.so.%{nvidia-version}"
        ln -sf "libvdpau_nvidia.so.%{nvidia-version}" \
            "$LIBDIR/vdpau/libvdpau_nvidia.so.1"
        ln -sf "libvdpau_nvidia.so.%{nvidia-version}" \
            "$LIBDIR/vdpau/libvdpau_nvidia.so"
    fi

    # libnvidia-egl-* / libnvidia-vulkan-* use NVIDIA-internal versioning
    # decoupled from the driver version — copy by glob instead of name.
    for pat in \
        'libnvidia-egl-wayland.so.*' \
        'libnvidia-egl-gbm.so.*' \
        'libnvidia-egl-xlib.so.*' \
        'libnvidia-egl-xcb.so.*' \
        'libnvidia-vulkan-producer.so.*' \
        'libnvidia-pkcs11*.so.*' \
        'libnvidia-nvvm.so.*' \
        'libnvidia-gtk*.so.*' \
    ; do
        for f in $pat; do
            [ -f "$f" ] && install -Dm755 "$f" "$LIBDIR/$f" || true
        done
    done

    for lib in "$LIBDIR"/lib*.so.%{nvidia-version}; do
        [ -f "$lib" ] || continue
        base=$(basename "$lib")
        soname=${base%.%{nvidia-version}}
        major_link=${soname}.1
        ln -sf "$base" "$LIBDIR/$soname"
        ln -sf "$base" "$LIBDIR/$major_link"
    done
    # libcuda's SONAME is libcuda.so.1, not libcuda.so.
    [ -e "$LIBDIR/libcuda.so.1" ] || ln -sf "libcuda.so.%{nvidia-version}" "$LIBDIR/libcuda.so.1"

    # Userspace tools shipped in the .run payload — install-commands above
    # only handle libraries, kernel modules, firmware, and ICDs, so without
    # this loop /usr/bin/nvidia-smi is absent. nvidia-modprobe is 0755, not
    # 4755: modules load at boot via /etc/modules-load.d, so an unprivileged
    # process never needs to invoke it.
    BINDIR="%{install-root}/usr/bin"
    install -d "$BINDIR"
    for bin in \
        nvidia-smi \
        nvidia-debugdump \
        nvidia-modprobe \
        nvidia-persistenced \
        nvidia-cuda-mps-control \
        nvidia-cuda-mps-server \
        nvidia-powerd \
        nvidia-settings \
    ; do
        [ -f "$bin" ] && install -Dm755 "$bin" "$BINDIR/$bin" || true
    done

    # nvidia-settings desktop file and icon
    if [ -f nvidia-settings.desktop ]; then
        install -Dm644 nvidia-settings.desktop \
            "%{install-root}/usr/share/applications/nvidia-settings.desktop"
    fi
    if [ -f nvidia-settings.png ]; then
        install -Dm644 nvidia-settings.png \
            "%{install-root}/usr/share/pixmaps/nvidia-settings.png"
    fi

    if [ -f nvidia_icd.json ]; then
        install -Dm644 nvidia_icd.json \
            "%{install-root}/usr/share/vulkan/icd.d/nvidia_icd.json"
    fi

    for f in nvidia_layers.json; do
        [ -f "$f" ] && install -Dm644 "$f" \
            "%{install-root}/usr/share/vulkan/implicit_layer.d/$f" || true
    done
    for f in 10_nvidia.json; do
        [ -f "$f" ] && install -Dm644 "$f" \
            "%{install-root}/usr/share/glvnd/egl_vendor.d/$f" || true
    done
    for f in 10_nvidia_wayland.json 15_nvidia_gbm.json; do
        [ -f "$f" ] && install -Dm644 "$f" \
            "%{install-root}/usr/share/egl/egl_external_platform.d/$f" || true
    done

    # GSP firmware: Turing+ offloads work to a chip-internal RISC-V
    # core; nvidia.ko loads the firmware at probe time.
    if [ -d firmware ]; then
        install -d "%{install-root}/usr/lib/firmware/nvidia/%{nvidia-version}"
        for fw in firmware/*.bin; do
            [ -f "$fw" ] && install -Dm644 "$fw" \
                "%{install-root}/usr/lib/firmware/nvidia/%{nvidia-version}/$(basename $fw)" || true
        done
    fi

    # OpenCL ICD: allows the OpenCL ICD loader to find the NVIDIA implementation.
    # Path /etc/OpenCL/vendors/ is the ocl-icd default search path.
    if [ -f nvidia.icd ]; then
        install -Dm644 nvidia.icd \
            "%{install-root}/etc/OpenCL/vendors/nvidia.icd"
    fi

    # Power management: save/restore GPU state across suspend and hibernate.
    # Without these the GPU context is lost on resume, causing hard locks.
    SYSTEMD_SYSTEM="%{install-root}/usr/lib/systemd/system"
    SYSTEMD_SLEEP="%{install-root}/usr/lib/systemd/system-sleep"
    install -d "$SYSTEMD_SYSTEM" "$SYSTEMD_SLEEP"
    for svc in \
        nvidia-hibernate.service \
        nvidia-resume.service \
        nvidia-suspend.service \
        nvidia-suspend-then-hibernate.service \
    ; do
        [ -f "$svc" ] && install -Dm644 "$svc" "$SYSTEMD_SYSTEM/$svc" || true
    done
    if [ -f nvidia-sleep.sh ]; then
        install -Dm755 nvidia-sleep.sh "$SYSTEMD_SLEEP/nvidia"
    fi

    # NVIDIA's SLA permits redistribution of the userspace libs only if
    # the EULA travels with them.
    if [ -f LICENSE ]; then
        install -Dm644 LICENSE \
            "%{install-root}/usr/share/doc/nvidia/LICENSE"
    fi
