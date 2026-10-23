kind: autotools
description: |
  Open Virtual Machine Tools for virtual machines hosted on VMware, including
  desktop integration (KMS auto-resolution, drag-and-drop/clipboard, vmhgfs-fuse).

sources:
- kind: tar
  url: github_files:vmware/open-vm-tools/releases/download/stable-13.1.0/open-vm-tools-13.1.0-25218885.tar.gz
  ref: 67a23d505aca77127b081445f758e269b1009e8824cf7f6f2d6efafb0b14d0fd
- kind: patch
  path: patches/open-vm-tools/sigc++3.patch
- kind: patch
  path: patches/open-vm-tools/gcc16.patch

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/rpcsvc-proto.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:sdk/gtk.bst
- gnome-build-meta.bst:core-deps/gtkmm.bst
- freedesktop-sdk.bst:components/fuse3.bst
- freedesktop-sdk.bst:components/libdrm.bst
- freedesktop-sdk.bst:components/libtirpc.bst
- freedesktop-sdk.bst:components/libtool.bst
- freedesktop-sdk.bst:components/linux-pam.bst
- freedesktop-sdk.bst:components/openssl.bst
- freedesktop-sdk.bst:components/pciutils.bst
- freedesktop-sdk.bst:components/procps.bst
- freedesktop-sdk.bst:components/systemd.bst
- freedesktop-sdk.bst:components/xorg-lib-x11.bst
- freedesktop-sdk.bst:components/xorg-lib-xext.bst
- freedesktop-sdk.bst:components/xorg-lib-xi.bst
- freedesktop-sdk.bst:components/xorg-lib-xinerama.bst
- freedesktop-sdk.bst:components/xorg-lib-xrandr.bst
- freedesktop-sdk.bst:components/xorg-lib-xrender.bst
- freedesktop-sdk.bst:components/xorg-lib-xtst.bst

variables:
  conf-local: >-
    CPPFLAGS="-I%{includedir}/drm"
    --sbindir=%{bindir}
    --disable-static
    --disable-deploypkg
    --disable-vgauth
    --disable-containerinfo
    --disable-docs
    --disable-tests
    --enable-resolutionkms
    --enable-servicediscovery
    --enable-vmwgfxctrl
    --with-fuse=fuse3
    --with-gtk4
    --without-icu
    --with-tirpc
    --without-dnet
    --without-xmlsec1
    --without-kernel-modules
    --with-udev-rules-dir=%{indep-libdir}/udev/rules.d

config:
  install-commands:
    (>):
    - |
      # Replace upstream generic PAM config (which references deprecated pam_unix_auth/acct)
      install -Dm644 /dev/null "%{install-root}%{sysconfdir}/pam.d/vmtoolsd"
      cat > "%{install-root}%{sysconfdir}/pam.d/vmtoolsd" <<'EOF'
      #%PAM-1.0
      auth       include      system-auth
      account    required     pam_nologin.so
      account    include      system-auth
      EOF
    - |
      chmod a-x "%{install-root}%{indep-libdir}/udev/rules.d/99-vmware-scsi-udev.rules" 2>/dev/null || true
      if [ -f "%{install-root}%{sysconfdir}/xdg/autostart/vmware-user.desktop" ]; then
        sed -i 's|^Encoding.*$||g' "%{install-root}%{sysconfdir}/xdg/autostart/vmware-user.desktop"
      fi
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system/vmtoolsd.service"
      cat > "%{install-root}%{indep-libdir}/systemd/system/vmtoolsd.service" <<'EOF'
      [Unit]
      Description=Service for virtual machines hosted on VMware
      Documentation=http://github.com/vmware/open-vm-tools
      ConditionVirtualization=vmware
      Before=display-manager.service

      [Service]
      ExecStart=/usr/bin/vmtoolsd
      TimeoutStopSec=5

      [Install]
      WantedBy=multi-user.target
      EOF
    - |
      install -Dm644 /dev/null '%{install-root}%{indep-libdir}/systemd/system/run-vmblock\x2dfuse.mount'
      cat > '%{install-root}%{indep-libdir}/systemd/system/run-vmblock\x2dfuse.mount' <<'EOF'
      [Unit]
      Description=VMware vmblock Fuse Mount
      Documentation=https://github.com/vmware/open-vm-tools/blob/master/open-vm-tools/vmblock-fuse/design.txt
      DefaultDependencies=no
      Before=umount.target vmtoolsd.service
      ConditionVirtualization=vmware
      After=sys-fs-fuse-connections.mount
      Wants=vmtoolsd.service

      [Mount]
      What=vmware-vmblock-fuse
      Where=/run/vmblock-fuse
      Type=fuse
      Options=subtype=vmware-vmblock,default_permissions,allow_other

      [Install]
      WantedBy=multi-user.target
      EOF
    - |
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/modules-load.d/open-vm-tools.conf"
      cat > "%{install-root}%{indep-libdir}/modules-load.d/open-vm-tools.conf" <<'EOF'
      fuse
      EOF
    - |
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-open-vm-tools.preset"
      cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-open-vm-tools.preset" <<'EOF'
      enable vmtoolsd.service
      enable run-vmblock\x2dfuse.mount
      EOF

public:
  initial-script:
    script: |
      #!/bin/bash
      set -eu
      sysroot="${1}"
      chmod 4755 "${sysroot}%{bindir}/vmware-user-suid-wrapper"
