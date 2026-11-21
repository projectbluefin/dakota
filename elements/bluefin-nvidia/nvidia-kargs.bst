kind: manual
description: |
  Kernel arguments required for NVIDIA + Wayland on a bootc image.

  The GNOME OS initramfs is built upstream without knowledge of NVIDIA,
  so /etc/modprobe.d/blacklist-nouveau.conf is not honored during the
  initramfs phase. Without rd.driver.blacklist nouveau claims the GPU
  before pivot_root, after which nvidia-drm cannot attach.

  The NVIDIA modules are not in the initramfs, so simpledrm is the only
  display there. It must stay enabled: on a machine whose only GPU is
  NVIDIA it is what draws the LUKS passphrase prompt and any emergency
  output. plymouth.use-simpledrm=1 makes Plymouth use it at once instead
  of waiting out DeviceTimeout for a native driver that cannot arrive
  before the root is unlocked. nvidia-drm with fbdev=1 takes the
  framebuffer over from simpledrm when it loads after pivot_root.

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
        "plymouth.use-simpledrm=1",
    ]
    EOF
