kind: manual
description: |
  Opt-in transparent zstd:1 compression for the Btrfs root filesystem.

  Under composefs there is no fstab entry for the root filesystem, so its
  mount options come only from rootflags= on the kernel command line
  (projectbluefin/dakota#1294). A rootflags= karg in kargs.d cannot be limited
  to Btrfs and would stop a non-Btrfs root from mounting, so a oneshot unit
  remounts /var instead; /var, /etc and /sysroot share one superblock.

  The unit is disabled by preset; `ujust toggle-btrfs-compression` enables it.
  Compressed composefs objects make the false fs-verity "FILE CORRUPTED"
  kernel messages of bootc-dev/bootc#2471 (projectbluefin/dakota#1832) more
  frequent, which is why it is not on by default.

sources:
- kind: local
  path: files/btrfs-compression

build-depends:
- core/sandbox-tools.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm644 dakota-btrfs-compression.service \
            "%{install-root}%{indep-libdir}/systemd/system/dakota-btrfs-compression.service"
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-btrfs-compression.preset"
    cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-btrfs-compression.preset" <<'EOF'
    disable dakota-btrfs-compression.service
    EOF
