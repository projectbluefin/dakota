kind: manual
description: |
  Create /dev/nvidia* device nodes before the display manager starts.
  The NVIDIA kernel modules do not create their own nodes; without this
  the GDM greeter races the first root NVML client for them and NVIDIA
  EGL init fails.

build-depends:
- core/sandbox-tools.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- bluefin-nvidia/nvidia-drivers.bst

sources:
- kind: local
  path: files/nvidia-device-nodes

variables:
  # Required: the default strip hook runs freedesktop-sdk-stripper,
  # which is not staged in this element's minimal deps.
  strip-binaries: ''

config:
  install-commands:
  - |
    install -Dm644 nvidia-device-nodes.service \
        "%{install-root}%{indep-libdir}/systemd/system/nvidia-device-nodes.service"
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-nvidia-device-nodes.preset"
    cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-nvidia-device-nodes.preset" <<'PRESET'
    enable nvidia-device-nodes.service
    PRESET
