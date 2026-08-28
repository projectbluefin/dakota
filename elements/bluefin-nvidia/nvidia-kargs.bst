kind: manual
description: |
  Kernel arguments required for NVIDIA + Wayland on a bootc image.

  The GNOME OS initramfs is built upstream without knowledge of NVIDIA,
  so /etc/modprobe.d/blacklist-nouveau.conf is not honored during the
  initramfs phase. Without rd.driver.blacklist nouveau (or simpledrm)
  claims the framebuffer before pivot_root, after which nvidia-drm
  cannot attach — the symptom is a black screen unless the user adds
  `nomodeset` manually at the bootloader.

  bootc applies these from /usr/lib/bootc/kargs.d/ on switch/upgrade.

build-depends:
- core/sandbox-tools.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    install -d "%{install-root}/usr/lib/bootc/kargs.d"
    cat > "%{install-root}/usr/lib/bootc/kargs.d/10-nvidia.toml" <<'EOF'
    kargs = [
        "rd.driver.blacklist=nouveau",
        "modprobe.blacklist=nouveau",
        "nvidia-drm.modeset=1",
        "nvidia-drm.fbdev=1",
        "initcall_blacklist=simpledrm_platform_driver_init",
    ]
    EOF
