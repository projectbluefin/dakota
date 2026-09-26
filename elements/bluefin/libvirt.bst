# gnome-build-meta dropped core-deps/libvirt.bst together with GNOME Boxes on
# master (GNOME 52), so Dakota owns this recipe based on gnome-51. Dependencies
# are remapped to Dakota's build stack, and PolicyKit is explicitly enabled:
# GNOME's project-wide --auto-features=enabled is not inherited here.
# ujust setup-virtualization (files/just-overrides/devmode.py)
# relies on the modular virt*d units, the firewalld libvirt zone, the qemu
# sysusers account, and every unit being disabled by default.
kind: meson

sources:
- kind: git_repo
  url: gitlab:libvirt/libvirt.git
  track: 'v*.*.*'
  exclude:
  - '*rc*'
  ref: v12.7.0-0-gf639bc728b15e7a5f26b84861098c13a62dd5e98
- kind: git_module
  url: gitlab:keycodemap/keycodemapdb.git
  path: subprojects/keycodemapdb
  ref: 22b8996dba9041874845c7446ce89ec4ae2b713d
- kind: local
  path: files/libvirt/80-libvirt.preset

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- gnome-build-meta.bst:core-deps/rpcsvc-proto.bst
- freedesktop-sdk.bst:components/bash-completion.bst
- freedesktop-sdk.bst:components/libxslt.bst
- freedesktop-sdk.bst:components/python3.bst
- freedesktop-sdk.bst:components/python3-docutils.bst
- freedesktop-sdk.bst:components/perl.bst
- freedesktop-sdk.bst:components/sed.bst

# Libvirt talks to PolicyKit over D-Bus; enabled mode needs no polkit headers.
# Keep its authorization service in the runtime closure, not just the desktop.
runtime-depends:
- freedesktop-sdk.bst:components/polkit.bst

depends:
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:core-deps/dnsmasq.bst
- gnome-build-meta.bst:core-deps/ebtables.bst
- gnome-build-meta.bst:core-deps/qemu.bst
- gnome-build-meta.bst:core-deps/libpcap.bst
- gnome-build-meta.bst:core-deps/libssh2.bst
- gnome-build-meta.bst:core-deps/slirp-helper.bst
- freedesktop-sdk.bst:components/audit.bst
- freedesktop-sdk.bst:components/curl.bst
- freedesktop-sdk.bst:components/cyrus-sasl.bst
- freedesktop-sdk.bst:components/dbus.bst
- freedesktop-sdk.bst:components/dmidecode.bst
- freedesktop-sdk.bst:components/fuse3.bst
- freedesktop-sdk.bst:components/gnutls.bst
- freedesktop-sdk.bst:components/iproute2.bst
- freedesktop-sdk.bst:components/libnl.bst
- freedesktop-sdk.bst:components/libtirpc.bst
- freedesktop-sdk.bst:components/libxml2.bst
- freedesktop-sdk.bst:components/lvm2.bst
- freedesktop-sdk.bst:components/open-iscsi.bst
- freedesktop-sdk.bst:components/openssh.bst
- freedesktop-sdk.bst:components/parted.bst
- freedesktop-sdk.bst:components/systemd.bst
- freedesktop-sdk.bst:components/xorg-lib-pciaccess.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  # gnome-build-meta defines runstatedir project-wide; Dakota's project does not.
  runstatedir: /run
  meson-local: >-
    -Drunstatedir=%{runstatedir}
    -Dapparmor=enabled
    -Dapparmor_profiles=enabled
    -Daudit=enabled
    -Dbash_completion=enabled
    -Dcapng=disabled
    -Dcurl=enabled
    -Ddriver_bhyve=disabled
    -Ddriver_esx=disabled
    -Ddriver_hyperv=disabled
    -Ddriver_libxl=disabled
    -Ddriver_lxc=disabled
    -Ddriver_ch=disabled
    -Ddriver_vz=disabled
    -Ddtrace=disabled
    -Dfuse=enabled
    -Dglusterfs=disabled
    -Dlibiscsi=disabled
    -Dlibpcap=enabled
    -Dlibssh2=enabled
    -Dlibssh=disabled
    -Dnetcf=disabled
    -Dnumactl=disabled
    -Dnumad=disabled
    -Dopenwsman=disabled
    -Dpolkit=enabled
    -Dsasl=enabled
    -Dsanlock=disabled
    -Dsecdriver_apparmor=enabled
    -Dsecdriver_selinux=disabled
    -Dselinux=disabled
    -Dstorage_disk=enabled
    -Dstorage_gluster=disabled
    -Dstorage_iscsi=enabled
    -Dstorage_iscsi_direct=disabled
    -Dstorage_rbd=disabled
    -Dstorage_vstorage=disabled
    -Dstorage_zfs=disabled
    -Dwireshark_dissector=disabled
    -Dnbdkit=disabled
    -Dnbdkit_config_default=disabled
    -Dno_git=true
    -Dtests=disabled
    -Dexpensive_tests=disabled
    -Dgit_werror=disabled

config:
  install-commands:
    (>):
    - |
      presetdir="$(pkg-config --variable=systemdsystempresetdir systemd)"
      install -Dm644 -t "%{install-root}${presetdir}" 80-libvirt.preset
    - |
      # Fail the build if non-root management loses PolicyKit again (#1669).
      # These are upstream-generated outputs, not permission/auth overrides.
      test -s "%{install-root}%{prefix}/share/polkit-1/actions/org.libvirt.unix.policy"
      test -s "%{install-root}%{prefix}/share/polkit-1/actions/org.libvirt.api.policy"
      test -s "%{install-root}%{prefix}/share/polkit-1/rules.d/50-libvirt.rules"
      for driver in qemu interface network nodedev nwfilter secret storage proxy; do
        grep -Fx 'SocketMode=0666' "%{install-root}%{prefix}/lib/systemd/system/virt${driver}d.socket"
        grep -Fx '#auth_unix_rw = "polkit"' "%{install-root}%{sysconfdir}/libvirt/virt${driver}d.conf"
      done
