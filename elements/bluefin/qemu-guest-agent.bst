kind: manual
description: |
  Service and udev rule for the QEMU Guest Agent (qemu-ga). The binary comes
  from freedesktop-sdk-extra's qemu, which the image already ships through
  bluefin/virtualization.bst, so this adds no packages of its own.

  The unit matches Fedora's: udev starts it when the host exposes the
  org.qemu.guest_agent.0 virtio-serial port, and it stops with the port. No
  virtualization condition: the port only exists when a host offers the
  channel, under KVM or plain QEMU emulation alike.

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
    install -d "%{install-root}%{indep-libdir}/systemd/system"
    cat > "%{install-root}%{indep-libdir}/systemd/system/qemu-guest-agent.service" <<'EOF'
    [Unit]
    Description=QEMU Guest Agent
    Documentation=man:qemu-ga(8)
    BindsTo=dev-virtio\x2dports-org.qemu.guest_agent.0.device
    After=dev-virtio\x2dports-org.qemu.guest_agent.0.device
    IgnoreOnIsolate=True

    [Service]
    UMask=0077
    ExecStart=%{bindir}/qemu-ga --method=virtio-serial --path=/dev/virtio-ports/org.qemu.guest_agent.0
    Restart=always
    RestartSec=0

    [Install]
    WantedBy=dev-virtio\x2dports-org.qemu.guest_agent.0.device
    EOF
  - |
    install -d "%{install-root}%{indep-libdir}/udev/rules.d"
    cat > "%{install-root}%{indep-libdir}/udev/rules.d/99-qemu-guest-agent.rules" <<'EOF'
    SUBSYSTEM=="virtio-ports", ATTR{name}=="org.qemu.guest_agent.0", TAG+="systemd", ENV{SYSTEMD_WANTS}+="qemu-guest-agent.service"
    EOF
