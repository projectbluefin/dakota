# gnome-build-meta's oci/initramfs.bst, replaced so it can run inside
# BuildBarn's chroot sandbox.
#
# bb_runner chroots into the action's input root, which has no procfs. Two
# steps here depend on one:
#
#   - prepare-image.sh drives systemd-firstboot, which exits 1 after only
#     warning that it cannot read the kernel command line;
#   - generate-initramfs's 50-kmod module uses bash process substitution, which
#     needs /dev/fd -> /proc/self/fd:
#       module.sh: line 65: /dev/fd/63: No such file or directory
#
# Mount a private procfs for the element when the sandbox has none. It shows
# this action's own processes only, so the build stays hermetic; binding the
# host's /proc would not. A sandbox that already has /proc (a local `just bst
# build`) is untouched, so this changes nothing outside remote execution.
#
# Drop this override once bb_runner mounts /proc itself
# (bb-remote-execution#115); upstream's element then works unchanged.
kind: script

build-depends:
- freedesktop-sdk.bst:components/util-linux.bst
- gnome-build-meta.bst:gnomeos/generate-initramfs.bst
- gnome-build-meta.bst:oci/initramfs/deps.bst
- gnome-build-meta.bst:oci/initramfs/initial-scripts.bst
- freedesktop-sdk.bst:components/fakecap.bst
- freedesktop-sdk.bst:vm/prepare-image.bst

variables:
  sysroot-seed: 9473a621-1617-4679-87e5-031afef28359

environment:
  LD_PRELOAD: /usr/libexec/fakecap/fakecap.so
  FAKECAP_DB: /fakecap
  ZSTDFLAGS: -T%{max-jobs}
  DLOPEN_NOTE_IGNORE: archive:fido2:qrencode:ip4tc
  INITRD_MODE: oci

environment-nocache:
- ZSTDFLAGS

config:
  commands:
  - |
    if [ ! -r /proc/self/status ]; then
      mount -t proc proc /proc
    fi
    [ -e /dev/fd ] || ln -sfn /proc/self/fd /dev/fd
  - mkdir -p /fakecap
  - |
    prepare-image.sh \
       --seed "%{sysroot-seed}" \
       --noroot --noboot >/dev/null

  - |
    version="$(ls -1 /lib/modules | head -n1)"
    generate-initramfs /initramfs-root "${version}" "%{libdir}" "%{libdir}/systemd"

  - |
    (
      cd /initramfs-root
      find . -print0 | sort -z | cpio --reproducible --null -H newc -o --quiet | zstd ${ZSTDFLAGS} >/initramfs.img
    )

  - |
    case '%{arch}' in
      x86_64)
        mkdir -p /microcode/kernel/x86/microcode
        cat /usr/lib/firmware/amd-ucode/microcode_amd*.bin >/microcode/kernel/x86/microcode/AuthenticAMD.bin
        cp /usr/lib/firmware/intel-ucode/GenuineIntel.bin /microcode/kernel/x86/microcode/GenuineIntel.bin
        (
          cd /microcode
          find . -print0 | sort -z | cpio --reproducible --null -H newc -o --quiet >/microcode.img
        )
      ;;
    esac

  - |
    version="$(ls -1 /lib/modules | head -n1)"
    mkdir -p "%{install-root}/usr/lib/modules/${version}"
    initrds=()
    case '%{arch}' in
      x86_64)
        initrds+=(/microcode.img)
        ;;
    esac
    initrds+=(/initramfs.img)
    cat "${initrds[@]}" >"%{install-root}/usr/lib/modules/${version}/initramfs.img"

  - |
    # Leave no mount behind: bb_runner tears down this input root after the
    # action, and a procfs still mounted inside it stalls that teardown.
    if mountpoint -q /proc 2>/dev/null; then
      umount /proc || umount -l /proc || true
    fi
