kind: manual
description: |
  Daemons for Linux guests on Microsoft Hyper-V, built from the kernel's
  tools/hv:
  - hv_kvp_daemon (key-value pairs: guest info, IP injection)
  - hv_vss_daemon (filesystem freeze for host-initiated snapshots)
  - hv_fcopy_uio_daemon (host-to-guest file copy; x86_64 only upstream)

  Units and udev rules follow Fedora's hyperv-daemons packaging; tools/hv
  ships none. KVP and VSS start from udev when their vmbus device appears,
  file copy is enabled by preset and gated on its vmbus device path.

# Same source as core/linux-fdsdk.bst (url, track, exclude and ref), so the
# kernel's fetched tree and source cache are reused. scripts/update_sources.py
# tracks this element alongside the kernel with the same pattern; keep url,
# track and exclude identical to the kernel's (scripts/test_update_sources.py
# enforces it). Gaming variants ship the OGC kernel instead; one tree serves
# both because these daemons talk to the kernel only through stable userspace
# ABI (the vmbus/hv_kvp and vmbus/hv_vss misc devices and uio_hv_generic),
# which is why distributions ship one tools/hv build for every kernel.
sources:
- kind: git_repo
  url: kernel:linux/kernel/git/stable/linux.git
  track: v7.3*
  exclude:
  - v7.3-rc*
  ref: v7.3-0-gc03c1a14507dfaf8b856c2608f9ac216021fc222
- kind: local
  path: files/hyperv
  directory: dakota-hyperv

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
- freedesktop-sdk.bst:bootstrap/linux-headers.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

runtime-depends:
# nmcli, for the KVP helper scripts in files/hyperv.
- freedesktop-sdk.bst:components/networkmanager.bst

variables:
  # tools/hv picks its targets from ARCH (hv_fcopy_uio_daemon is x86 only);
  # pass the target instead of letting it fall back to `uname -m`.
  hv-make-args: >-
    -C tools/hv
    ARCH=%{arch}
    sbindir=%{bindir}
    libexecdir=%{libexecdir}
    sharedstatedir=%{localstatedir}/lib

config:
  build-commands:
  - make %{hv-make-args}

  install-commands:
  - make %{hv-make-args} DESTDIR="%{install-root}" install
  - |
    # Upstream's KVP helper scripts assume network-scripts, ifup/ifdown and a
    # real /etc/resolv.conf. Replace them with NetworkManager versions so host
    # IP injection and the guest IP/DNS/DHCP queries work on Dakota.
    for script in hv_set_ifconfig hv_get_dhcp_info hv_get_dns_info; do
      install -Dm755 "dakota-hyperv/${script}" "%{install-root}%{libexecdir}/hypervkvpd/${script}"
    done
  - |
    # /var is not image content; tmpfiles creates the KVP pool directory.
    rm -rf "%{install-root}%{localstatedir}"
    install -d "%{install-root}%{indep-libdir}/tmpfiles.d"
    cat > "%{install-root}%{indep-libdir}/tmpfiles.d/hyperv-daemons.conf" <<'EOF'
    d /var/lib/hyperv 0755 root root -
    EOF
  - |
    install -d "%{install-root}%{indep-libdir}/udev/rules.d"
    cat > "%{install-root}%{indep-libdir}/udev/rules.d/70-hypervkvp.rules" <<'EOF'
    SUBSYSTEM=="misc", KERNEL=="vmbus/hv_kvp", TAG+="systemd", ENV{SYSTEMD_WANTS}+="hypervkvpd.service"
    EOF
    cat > "%{install-root}%{indep-libdir}/udev/rules.d/70-hypervvss.rules" <<'EOF'
    SUBSYSTEM=="misc", KERNEL=="vmbus/hv_vss", TAG+="systemd", ENV{SYSTEMD_WANTS}+="hypervvssd.service"
    EOF
  - |
    install -d "%{install-root}%{indep-libdir}/systemd/system"
    cat > "%{install-root}%{indep-libdir}/systemd/system/hypervkvpd.service" <<'EOF'
    [Unit]
    Description=Hyper-V KVP daemon
    ConditionVirtualization=microsoft
    BindsTo=sys-devices-virtual-misc-vmbus\x21hv_kvp.device
    After=sys-devices-virtual-misc-vmbus\x21hv_kvp.device
    RequiresMountsFor=/var/lib/hyperv
    Before=cloud-init-local.service
    IgnoreOnIsolate=1

    [Service]
    Type=simple
    ExecStart=%{bindir}/hv_kvp_daemon -n
    EOF
    cat > "%{install-root}%{indep-libdir}/systemd/system/hypervvssd.service" <<'EOF'
    [Unit]
    Description=Hyper-V VSS daemon
    ConditionVirtualization=microsoft
    BindsTo=sys-devices-virtual-misc-vmbus\x21hv_vss.device
    IgnoreOnIsolate=1

    [Service]
    ExecStart=%{bindir}/hv_vss_daemon -n
    EOF

  (?):
  - arch == "x86_64":
      install-commands:
        (>):
        - |
          # Since Linux 6.10 file copy runs over uio_hv_generic; there is no
          # vmbus/hv_fcopy device for udev to match, so the unit is enabled by
          # preset and binds the driver to the fcopy vmbus device itself.
          cat > "%{install-root}%{indep-libdir}/systemd/system/hypervfcopyd.service" <<'EOF'
          [Unit]
          Description=Hyper-V FCOPY daemon
          ConditionPathExists=/sys/bus/vmbus/devices/eb765408-105f-49b6-b4aa-c123b64d17d4/
          IgnoreOnIsolate=1

          [Service]
          ExecStartPre=/bin/sh -c '[ ! -d /sys/bus/vmbus/devices/eb765408-105f-49b6-b4aa-c123b64d17d4/uio ] && modprobe uio_hv_generic && echo 34d14be3-dee4-41c8-9ae7-6b174977c192 > /sys/bus/vmbus/drivers/uio_hv_generic/new_id ||:'
          ExecStart=%{bindir}/hv_fcopy_uio_daemon -n

          [Install]
          WantedBy=multi-user.target
          EOF
          install -d "%{install-root}%{indep-libdir}/systemd/system-preset"
          cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-hyperv-daemons.preset" <<'EOF'
          enable hypervfcopyd.service
          EOF
