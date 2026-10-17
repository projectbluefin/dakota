kind: manual
description: |
  Suite of daemons for Linux guests running on Microsoft Hyper-V:
  - hv_kvp_daemon (Key-Value Pair daemon, IP injection)
  - hv_vss_daemon (Volume Shadow Copy / snapshot daemon)
  - hv_fcopy_uio_daemon (Guest file copy daemon)

sources:
- kind: git_repo
  url: kernel:linux/kernel/git/stable/linux.git
  track: v7.2.*
  ref: v7.2.9-0-g5fce161649b4d779d1b76d9fcd52dc77779774b8

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
- freedesktop-sdk.bst:bootstrap/linux-headers.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  build-commands:
  - |
    cd tools/hv
    make sbindir=%{bindir}

  install-commands:
  - |
    cd tools/hv
    make install DESTDIR="%{install-root}" sbindir=%{bindir} libexecdir=%{libexecdir} sharedstatedir=/var/lib
  - |
    # Clean up empty /var directory created by make install
    rm -rf "%{install-root}/var"
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/tmpfiles.d/hyperv.conf"
    cat > "%{install-root}%{indep-libdir}/tmpfiles.d/hyperv.conf" <<'EOF'
    d /var/lib/hyperv 0755 root root -
    EOF
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/udev/rules.d/70-hypervkvp.rules"
    cat > "%{install-root}%{indep-libdir}/udev/rules.d/70-hypervkvp.rules" <<'EOF'
    SUBSYSTEM=="misc", KERNEL=="vmbus/hv_kvp", TAG+="systemd", ENV{SYSTEMD_WANTS}+="hypervkvpd.service"
    EOF
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/udev/rules.d/70-hypervvss.rules"
    cat > "%{install-root}%{indep-libdir}/udev/rules.d/70-hypervvss.rules" <<'EOF'
    SUBSYSTEM=="misc", KERNEL=="vmbus/hv_vss", TAG+="systemd", ENV{SYSTEMD_WANTS}+="hypervvssd.service"
    EOF
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/udev/rules.d/70-hypervfcopy.rules"
    cat > "%{install-root}%{indep-libdir}/udev/rules.d/70-hypervfcopy.rules" <<'EOF'
    SUBSYSTEM=="misc", KERNEL=="vmbus/hv_fcopy", TAG+="systemd", ENV{SYSTEMD_WANTS}+="hypervfcopyd.service"
    EOF
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system/hypervkvpd.service"
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
    ExecStart=/usr/bin/hv_kvp_daemon -n
    EOF
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system/hypervvssd.service"
    cat > "%{install-root}%{indep-libdir}/systemd/system/hypervvssd.service" <<'EOF'
    [Unit]
    Description=Hyper-V VSS daemon
    ConditionVirtualization=microsoft
    BindsTo=sys-devices-virtual-misc-vmbus\x21hv_vss.device
    IgnoreOnIsolate=1

    [Service]
    Type=simple
    ExecStart=/usr/bin/hv_vss_daemon -n
    EOF
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system/hypervfcopyd.service"
    cat > "%{install-root}%{indep-libdir}/systemd/system/hypervfcopyd.service" <<'EOF'
    [Unit]
    Description=Hyper-V FCOPY daemon
    ConditionPathExists=/sys/bus/vmbus/devices/eb765408-105f-49b6-b4aa-c123b64d17d4/
    IgnoreOnIsolate=1

    [Service]
    ExecStartPre=/bin/sh -c '[ ! -d /sys/bus/vmbus/devices/eb765408-105f-49b6-b4aa-c123b64d17d4/uio ] && modprobe uio_hv_generic && echo 34d14be3-dee4-41c8-9ae7-6b174977c192 > /sys/bus/vmbus/drivers/uio_hv_generic/new_id ||:'
    ExecStart=/usr/bin/hv_fcopy_uio_daemon -n

    [Install]
    WantedBy=multi-user.target
    EOF
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-hyperv-daemons.preset"
    cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-hyperv-daemons.preset" <<'EOF'
    enable hypervfcopyd.service
    EOF
