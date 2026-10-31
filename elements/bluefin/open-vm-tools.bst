kind: autotools
description: |
  Open Virtual Machine Tools for VMware guests, built without X11: vmtoolsd
  with power operations, guest info and time sync, Wayland display
  auto-resize through the resolutionKMS plugin (vmwgfx DRM, runs inside
  vmtoolsd), and vmhgfs-fuse shared folders.

  Not built: the X11 session agent (vmware-user and its setuid wrapper) with
  its copy/paste, drag-and-drop and X11 resolution plugins, so no gtk, gtkmm
  or X libraries. vmblock-fuse only serves drag-and-drop and is not shipped.
  Also off: VGAuth (SAML guest operations), service discovery, deployPkg
  (guest customization) and container info.

sources:
- kind: tar
  url: github_files:vmware/open-vm-tools/releases/download/stable-13.1.0/open-vm-tools-13.1.0-25218885.tar.gz
  ref: 67a23d505aca77127b081445f758e269b1009e8824cf7f6f2d6efafb0b14d0fd
- kind: patch
  path: patches/open-vm-tools/gcc16.patch

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/rpcsvc-proto.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- gnome-build-meta.bst:sdk/glib.bst
- freedesktop-sdk.bst:components/fuse3.bst
- freedesktop-sdk.bst:components/libdrm.bst
- freedesktop-sdk.bst:components/libtirpc.bst
- freedesktop-sdk.bst:components/linux-pam.bst
- freedesktop-sdk.bst:components/openssl.bst
- freedesktop-sdk.bst:components/systemd.bst

variables:
  # resolutionKMS includes <vmwgfx_drm.h> unprefixed; the kernel uAPI
  # headers put it in %{includedir}/drm, which libdrm's pkg-config flags
  # (%{includedir}/libdrm) do not cover.
  conf-local: >-
    CPPFLAGS="-I%{includedir}/drm"
    --sbindir=%{bindir}
    --disable-static
    --without-x
    --disable-deploypkg
    --disable-vgauth
    --disable-containerinfo
    --disable-servicediscovery
    --disable-docs
    --disable-tests
    --enable-resolutionkms
    --enable-vmwgfxctrl
    --with-fuse=fuse3
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
      # vmblock-fuse backs drag-and-drop, which this build does not have.
      rm "%{install-root}%{bindir}/vmware-vmblock-fuse"
    - |
      # Upstream's generic PAM file uses modules that no longer exist
      # (pam_unix_auth/pam_unix_acct). vmtoolsd authenticates vSphere guest
      # operations non-interactively, so use password-auth (as sshd does and
      # Fedora's vmtoolsd file does), not system-auth with its fingerprint step.
      cat > "%{install-root}%{sysconfdir}/pam.d/vmtoolsd" <<'EOF'
      #%PAM-1.0
      auth       substack     password-auth
      account    required     pam_nologin.so
      account    include      password-auth
      EOF
      chmod 0644 "%{install-root}%{sysconfdir}/pam.d/vmtoolsd"
    - |
      chmod a-x "%{install-root}%{indep-libdir}/udev/rules.d/99-vmware-scsi-udev.rules"
    - |
      install -d "%{install-root}%{indep-libdir}/systemd/system"
      cat > "%{install-root}%{indep-libdir}/systemd/system/vmtoolsd.service" <<'EOF'
      [Unit]
      Description=Service for virtual machines hosted on VMware
      Documentation=https://github.com/vmware/open-vm-tools
      ConditionVirtualization=vmware
      Before=display-manager.service

      [Service]
      ExecStart=%{bindir}/vmtoolsd
      TimeoutStopSec=5

      [Install]
      WantedBy=multi-user.target
      EOF
    - |
      install -d "%{install-root}%{indep-libdir}/systemd/system-preset"
      cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-open-vm-tools.preset" <<'EOF'
      enable vmtoolsd.service
      EOF
