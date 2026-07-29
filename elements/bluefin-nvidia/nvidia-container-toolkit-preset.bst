kind: manual
description: |
  Enable upstream's nvidia-cdi-refresh.{path,service} (shipped by
  bluefin-nvidia/nvidia-container-toolkit.bst) so the CDI spec at
  /var/run/cdi/nvidia.yaml is generated at boot and refreshed whenever
  the driver or toolkit binaries change.

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-nvidia-container-toolkit.preset"
    cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-nvidia-container-toolkit.preset" <<'PRESET'
    enable nvidia-cdi-refresh.path
    enable nvidia-cdi-refresh.service
    PRESET
