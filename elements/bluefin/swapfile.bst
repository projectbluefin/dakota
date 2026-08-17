kind: manual
description: |
  Disk-backed swapfile at /var/swap/swapfile: the backing store zswap fronts
  (kargs in bluefin/zswap-config.bst). Without a real swap device zswap is
  inert, and Dakota disables the GNOME OS zram default.

  A oneshot init service creates the file on first need (min(RAM/2, 8 GiB),
  dd-written for xfs/btrfs swapon compatibility, skipped on small disks); the
  .swap unit is pulled in via a static swap.target.wants symlink so existing
  installs pick it up on upgrade — presets only apply on first boot.

  /var/swap is created at runtime: bluefin-stack.bst integration wipes /var,
  and bootc lints against baked /var content.

sources:
- kind: local
  path: files/swapfile

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 bluefin-swapfile-init \
            "%{install-root}/usr/libexec/bluefin-swapfile-init"
  - |
    install -Dm644 bluefin-swapfile-init.service \
            "%{install-root}%{indep-libdir}/systemd/system/bluefin-swapfile-init.service"
  - |
    install -Dm644 var-swap-swapfile.swap \
            "%{install-root}%{indep-libdir}/systemd/system/var-swap-swapfile.swap"
  - |
    install -d "%{install-root}%{indep-libdir}/systemd/system/swap.target.wants"
    ln -sf ../var-swap-swapfile.swap \
           "%{install-root}%{indep-libdir}/systemd/system/swap.target.wants/var-swap-swapfile.swap"
  - "%{install-extra}"
