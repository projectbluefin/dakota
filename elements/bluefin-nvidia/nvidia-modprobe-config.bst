kind: manual
description: |
  Modprobe glue for NVIDIA on Wayland: enable KMS + fbdev, blacklist nouveau.

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    install -d "%{install-root}/etc/modprobe.d"
    # modeset=1 is mandatory for any Wayland compositor on NVIDIA and
    # must be set at module load time — setting it later has no effect.
    cat > "%{install-root}/etc/modprobe.d/nvidia.conf" <<'EOF'
    options nvidia-drm modeset=1 fbdev=1
    options nvidia NVreg_OpenRmEnableUnsupportedGpus=0
    options nvidia NVreg_EnableGpuFirmware=1
    # Required for nvidia-suspend/hibernate/resume services to save and
    # restore GPU memory. Without this the services run but GPU context
    # is lost on resume, causing hard locks. See gnome-build-meta !4685.
    options nvidia NVreg_PreserveVideoMemoryAllocations=1
    EOF

    # Order matters: nvidia → nvidia-modeset → nvidia-drm. Loading early
    # so we grab the framebuffer before any other DRM driver tries.
    install -d "%{install-root}/etc/modules-load.d"
    cat > "%{install-root}/etc/modules-load.d/nvidia.conf" <<'EOF'
    nvidia
    nvidia-modeset
    nvidia-drm
    nvidia-uvm
    EOF

    # nouveau and the proprietary driver race for /dev/dri/card0 if both
    # load — black screen / VESA fallback. Block nouveau outright.
    cat > "%{install-root}/etc/modprobe.d/blacklist-nouveau.conf" <<'EOF'
    blacklist nouveau
    options nouveau modeset=0
    EOF
