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
  url: nvidia:XFree86/Linux-x86_64/610.57.04/NVIDIA-Linux-x86_64-610.57.04.run
  ref: b2e935c66b83bb00c0c857bc8e0ee0fd52de9286b40c9cc1eec29a7ce7eb116d
  filename: NVIDIA-Linux-x86_64-610.57.04.run

variables:
  nvidia-version: '610.57.04'
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
    LIBDIR32="%{install-root}/usr/lib/i386-linux-gnu"
    install -d "$LIBDIR" "$LIBDIR/vdpau" "$LIBDIR32" "$LIBDIR32/vdpau"

    # Libraries and their symlinks come from the .run's .manifest (the
    # same metadata nvidia-installer uses), selected by TYPE and ARCH so
    # new libraries flow in on driver bumps. NATIVE rows install to
    # %{libdir}; COMPAT32 rows (payload files under 32/) install to
    # /usr/lib/i386-linux-gnu so 32-bit GL/Vulkan games get hardware
    # rendering — gaming/steam-libs-i686.bst ships the 32-bit GLVND and
    # Vulkan loader that dispatch to them. Not selected: GLVND/GLX/EGL
    # client libs (system libglvnd comes from freedesktop-sdk natively,
    # gaming/steam-libs-i686.bst for 32-bit), OPENCL_WRAPPER (ocl-icd
    # owns libOpenCL), Wine/Xorg-module/installer internals, and the
    # COMPAT32 GBM backend symlink (compositors are 64-bit; nothing
    # loads a 32-bit GBM backend).
    # Row shape: <name> <mode> <TYPE> <ARCH> [subdir/] [target] MODULE:<tag>
    # awk normalizes rows to fixed columns and flags anything it cannot
    # classify, so a changed manifest format fails the build loudly.
    # SONAME links the manifest does not declare are created by ldconfig
    # at compose integration time.
    install_manifest_arch() {
        arch="$1"
        destdir="$2"
        awk -v arch="$arch" '
            BEGIN {
                n = split("OPENGL_LIB CUDA_LIB NVCUVID_LIB ENCODEAPI_LIB" \
                          " UTILITY_LIB TLS_LIB OPENCL_LIB VDPAU_LIB", a, " ")
                for (i = 1; i <= n; i++) isfile[a[i]] = 1
                n = split("OPENGL_SYMLINK CUDA_SYMLINK NVCUVID_LIB_SYMLINK" \
                          " ENCODEAPI_LIB_SYMLINK UTILITY_LIB_SYMLINK" \
                          " OPENCL_LIB_SYMLINK VDPAU_SYMLINK" \
                          " GBM_BACKEND_LIB_SYMLINK", b, " ")
                for (i = 1; i <= n; i++) islink[b[i]] = 1
            }
            NF >= 4 && $2 ~ /^[0-9]+$/ && $4 == arch && ($3 in isfile || $3 in islink) {
                if ($3 == "GBM_BACKEND_LIB_SYMLINK" && arch != "NATIVE") next
                subdir = "-"; target = "-"; bad = 0
                for (i = 5; i <= NF; i++) {
                    if ($i ~ /^MODULE:/ || $i == "/") continue
                    else if ($i ~ /\/$/) subdir = $i
                    else if (target == "-") target = $i
                    else bad = 1
                }
                if (bad || ($3 in islink && target == "-") ||
                    ($3 == "GBM_BACKEND_LIB_SYMLINK" && target ~ /\//)) {
                    print "E", $0
                    next
                }
                kind = ($3 in isfile) ? "F" : ($3 == "GBM_BACKEND_LIB_SYMLINK" ? "G" : "L")
                print kind, $1, subdir, target
            }' .manifest | \
        while read -r kind name subdir target; do
            [ "$subdir" = "-" ] && subdir=""
            # COMPAT32 file rows name the payload path under ./32/; the
            # installed name is the basename either way.
            base="${name#./32/}"
            case "$kind" in
            E)
                echo "ERROR: unparseable .manifest row: $name $subdir $target" >&2
                exit 1
                ;;
            F)
                if [ ! -f "$name" ]; then
                    echo "ERROR: .manifest lists $name but it is not in the payload" >&2
                    exit 1
                fi
                install -Dm755 "$name" "$destdir/${subdir}${base}"
                ;;
            L)
                [ -z "$subdir" ] || [ -d "$destdir/$subdir" ] || install -d "$destdir/$subdir"
                ln -sf "$target" "$destdir/${subdir}${base}"
                ;;
            G)
                # FDSDK exposes GL/lib/gbm as a symlink to the Mesa extension's
                # GL/default/lib/gbm. Install into that target: creating a real
                # GL/lib/gbm here shadows Mesa's dri_gbm.so on hybrid systems.
                GBM_DIR="$destdir/GL/default/lib/gbm"
                install -d "$GBM_DIR"
                ln -srf "$destdir/$target" "$GBM_DIR/$base"
                ;;
            esac
        done
    }
    install_manifest_arch NATIVE "$LIBDIR"
    install_manifest_arch COMPAT32 "$LIBDIR32"

    # Userspace tools. nvidia-modprobe stays 0755 (not NVIDIA's 4755):
    # nvidia-device-nodes.service invokes it as root, so no unprivileged
    # process needs it.
    BINDIR="%{install-root}%{bindir}"
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

    # library_path is a bare soname, so this one JSON serves the 64-bit
    # and 32-bit Vulkan loaders alike; each resolves its own ELF class
    # through ld.so (the i386 dirs are on the ld path via
    # gaming/steam-native.bst's /etc/ld.so.conf.d/00-i386-linux-gnu.conf).
    if [ -f nvidia_icd.json ]; then
        install -Dm644 nvidia_icd.json \
            "%{install-root}/usr/share/vulkan/icd.d/nvidia_icd.json"
    fi

    for f in nvidia_layers.json; do
        [ -f "$f" ] && install -Dm644 "$f" \
            "%{install-root}/usr/share/vulkan/implicit_layer.d/$f" || true
    done
    # fdsdk's libglvnd searches only /etc/glvnd/egl_vendor.d and
    # %{libdir}/GL/glvnd/egl_vendor.d — never /usr/share. The GL dir is
    # a symlink into the Mesa extension tree that a real directory here
    # would shadow at OCI merge (see docs/skills/oci-layers.md), so the
    # load-bearing copy goes to /etc; /usr/share is convention only.
    # Upstream-Status: not-submitted (fdsdk libglvnd sets datadir=%{libdir}/GL)
    # Exit: when fdsdk libglvnd also searches /usr/share/glvnd/egl_vendor.d
    if [ ! -f 10_nvidia.json ]; then
        echo "ERROR: 10_nvidia.json missing from driver payload" >&2
        exit 1
    fi
    install -Dm644 10_nvidia.json \
        "%{install-root}%{sysconfdir}/glvnd/egl_vendor.d/10_nvidia.json"
    install -Dm644 10_nvidia.json \
        "%{install-root}%{datadir}/glvnd/egl_vendor.d/10_nvidia.json"
    # EGL external-platform JSONs (wayland, wayland2, gbm, xcb, xlib)
    # are manifest-driven like the libraries they activate.
    awk '$3 == "EGL_EXTERNAL_PLATFORM_JSON" { print $1 }' .manifest | \
    while read -r f; do
        if [ ! -f "$f" ]; then
            echo "ERROR: .manifest lists $f but it is not in the payload" >&2
            exit 1
        fi
        install -Dm644 "$f" \
            "%{install-root}%{datadir}/egl/egl_external_platform.d/$f"
    done
    # The loop above is vacuous if the manifest stops declaring these
    # rows; wayland and gbm are load-bearing for the session, so verify.
    for f in 10_nvidia_wayland.json 15_nvidia_gbm.json; do
        if [ ! -f "%{install-root}%{datadir}/egl/egl_external_platform.d/$f" ]; then
            echo "ERROR: expected EGL external-platform JSON $f was not installed" >&2
            exit 1
        fi
    done

    # Per-application quirk database. libnvidia-glcore has the path
    # compiled in version-stamped, so it cannot be relocated.
    awk '$3 == "APPLICATION_PROFILE" { print $1 }' .manifest | \
    while read -r f; do
        if [ ! -f "$f" ]; then
            echo "ERROR: .manifest lists $f but it is not in the payload" >&2
            exit 1
        fi
        install -Dm644 "$f" "%{install-root}%{datadir}/nvidia/$f"
    done
    # Vacuous if the manifest stops declaring these rows, and the loss
    # would be silent.
    if [ ! -f "%{install-root}%{datadir}/nvidia/nvidia-application-profiles-%{nvidia-version}-rc" ]; then
        echo "ERROR: application profiles were not installed" >&2
        exit 1
    fi

    # OptiX data blob; libnvoptix.so (OPENGL_LIB, above) fails at init
    # without it.
    if [ ! -f nvoptix.bin ]; then
        echo "ERROR: nvoptix.bin missing from driver payload" >&2
        exit 1
    fi
    install -Dm644 nvoptix.bin "%{install-root}%{datadir}/nvidia/nvoptix.bin"

    # DLSS/frame-gen under Proton: the PE halves dxvk-nvapi loads, to
    # nvidia-installer's default <opengl-libdir>/nvidia/wine. The ELF
    # half (libnvidia-ngx.so) comes from TYPE selection above.
    WINEDIR="$LIBDIR/nvidia/wine"
    install -d "$WINEDIR"
    awk '$3 == "WINE_LIB" && $4 == "NATIVE" { print $1 }' .manifest | \
    while read -r f; do
        if [ ! -f "$f" ]; then
            echo "ERROR: .manifest lists $f but it is not in the payload" >&2
            exit 1
        fi
        install -Dm755 "$f" "$WINEDIR/$f"
    done
    for f in nvngx.dll _nvngx.dll; do
        if [ ! -f "$WINEDIR/$f" ]; then
            echo "ERROR: expected NGX Wine library $f was not installed" >&2
            exit 1
        fi
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

    # Power management: save/restore VRAM across suspend/hibernate.
    # PreserveVideoMemoryAllocations=1 (nvidia-modprobe-config.bst) makes
    # these load-bearing: without the /proc/driver/nvidia/suspend
    # handshake they perform, the driver vetoes kernel PM outright
    # (nv_pmops_suspend returns -5) and the machine cannot sleep (#1118).
    # The payload stores all of this under systemd/, not the payload root.
    SYSTEMD_DIR="%{install-root}%{indep-libdir}/systemd"
    for svc in \
        nvidia-hibernate.service \
        nvidia-resume.service \
        nvidia-suspend.service \
        nvidia-suspend-then-hibernate.service \
    ; do
        if [ ! -f "systemd/system/$svc" ]; then
            echo "ERROR: $svc missing from driver payload" >&2
            exit 1
        fi
        install -Dm644 "systemd/system/$svc" "$SYSTEMD_DIR/system/$svc"
    done
    # The units ExecStart /usr/bin/nvidia-sleep.sh; the system-sleep hook
    # drives resume and the suspend-then-hibernate special cases.
    for f in systemd/nvidia-sleep.sh systemd/system-sleep/nvidia; do
        if [ ! -f "$f" ]; then
            echo "ERROR: $f missing from driver payload" >&2
            exit 1
        fi
    done
    install -Dm755 systemd/nvidia-sleep.sh "$BINDIR/nvidia-sleep.sh"
    install -Dm755 systemd/system-sleep/nvidia "$SYSTEMD_DIR/system-sleep/nvidia"
    # NVIDIA's no-freeze drop-ins: systemd freezes user sessions before
    # sleep, which deadlocks against the VT switch nvidia-sleep.sh does.
    for d in systemd/system/systemd-*.service.d; do
        if [ ! -d "$d" ]; then
            echo "ERROR: no nvidia-suspend-nofreeze drop-ins in payload" >&2
            exit 1
        fi
        install -Dm644 "$d/nvidia-suspend-nofreeze.conf" \
            "$SYSTEMD_DIR/system/$(basename "$d")/nvidia-suspend-nofreeze.conf"
    done

    # nvidia-powerd (Dynamic Boost) is inert without all three: unit,
    # D-Bus policy to own nvidia.powerd.server, and its data table.
    # nvidia-dbus.conf is typed DOCUMENTATION, so TYPE selection above
    # can never pick it up. Absent from the preset below but still
    # enabled: no catch-all preset rule exists, so systemd's default
    # policy enables anything with [Install]. That's fine - it exits 0
    # on hardware without Dynamic Boost, so nothing lands in failed.
    for f in systemd/system/nvidia-powerd.service nvidia-dbus.conf dlsnetparams.csv; do
        if [ ! -f "$f" ]; then
            echo "ERROR: $f missing from driver payload" >&2
            exit 1
        fi
    done
    install -Dm644 systemd/system/nvidia-powerd.service \
        "$SYSTEMD_DIR/system/nvidia-powerd.service"
    install -Dm644 nvidia-dbus.conf \
        "%{install-root}%{datadir}/dbus-1/system.d/nvidia-dbus.conf"
    install -Dm644 dlsnetparams.csv \
        "%{install-root}%{datadir}/nvidia/nvidia-powerd/dlsnetparams.csv"

    # NVIDIA's SLA permits redistribution of the userspace libs only if
    # the EULA travels with them.
    if [ -f LICENSE ]; then
        install -Dm644 LICENSE \
            "%{install-root}/usr/share/doc/nvidia/LICENSE"
    fi
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-nvidia-pm.preset"
    cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-nvidia-pm.preset" <<'PRESET'
    enable nvidia-suspend.service
    enable nvidia-resume.service
    enable nvidia-hibernate.service
    enable nvidia-suspend-then-hibernate.service
    PRESET
  # Fail the build if any installed NVIDIA ELF has an NVIDIA-internal
  # DT_NEEDED that the manifest TYPE selection above did not install
  # (e.g. a newly split-out library like libnvidia-gpucomp). Each arch
  # is checked against its own libdir; a 32-bit object must find its
  # deps in the i386 tree, never the native one.
  - |
    set -euo pipefail
    LIBDIR="%{install-root}%{libdir}"
    LIBDIR32="%{install-root}/usr/lib/i386-linux-gnu"
    BINDIR="%{install-root}%{bindir}"
    status=0
    check_closure() {
        depdir="$1"; shift
        for obj in "$@"; do
            { [ -f "$obj" ] && [ ! -L "$obj" ]; } || continue
            for dep in $(objdump -p "$obj" 2>/dev/null | awk '/NEEDED/{print $2}' || true); do
                case "$dep" in
                  libnvidia-*|libcuda.so*|libnvcuvid.so*|libnvoptix.so*)
                    if [ ! -e "$depdir/$dep" ]; then
                        echo "ERROR: $(basename "$obj") requires $dep, which is not installed in $depdir" >&2
                        status=1
                    fi
                    ;;
                esac
            done
        done
    }
    check_closure "$LIBDIR" "$LIBDIR"/lib*.so.* "$LIBDIR"/vdpau/lib*.so.* "$BINDIR"/*
    check_closure "$LIBDIR32" "$LIBDIR32"/lib*.so.* "$LIBDIR32"/vdpau/lib*.so.*
    exit "$status"
