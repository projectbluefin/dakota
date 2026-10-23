kind: manual
description: |
  Systemd service, udev rules, and preset for QEMU Guest Agent (qemu-ga).
  The binary is built and supplied by gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/qemu.bst.

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

runtime-depends:
- gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/qemu.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system/qemu-guest-agent.service"
    cat > "%{install-root}%{indep-libdir}/systemd/system/qemu-guest-agent.service" <<'EOF'
    [Unit]
    Description=QEMU Guest Agent
    Documentation=man:qemu-ga(8)
    ConditionVirtualization=kvm
    BindsTo=dev-virtio\x2dports-org.qemu.guest_agent.0.device
    After=dev-virtio\x2dports-org.qemu.guest_agent.0.device
    IgnoreOnIsolate=True

    [Service]
    UMask=0077
    ExecStart=/usr/bin/qemu-ga --method=virtio-serial --path=/dev/virtio-ports/org.qemu.guest_agent.0
    Restart=always
    RestartSec=0

    [Install]
    WantedBy=dev-virtio\x2dports-org.qemu.guest_agent.0.device
    EOF
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/udev/rules.d/99-qemu-guest-agent.rules"
    cat > "%{install-root}%{indep-libdir}/udev/rules.d/99-qemu-guest-agent.rules" <<'EOF'
    SUBSYSTEM=="virtio-ports", ATTR{name}=="org.qemu.guest_agent.0", TAG+="systemd", ENV{SYSTEMD_WANTS}="qemu-guest-agent.service"
    EOF
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-qemu-guest-agent.preset"
    cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-qemu-guest-agent.preset" <<'EOF'
    enable qemu-guest-agent.service
    EOF
