# liblxc — system-container runtime. incusd's LXC driver links this via
# `pkg-config lxc`. We build the 6.0 LTS line (matches Incus 7.x).
# Library + config only: the lxc-* CLI tools and templates are not needed,
# Incus drives liblxc directly.
kind: meson

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/pkg-config.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/libcap.bst
- freedesktop-sdk.bst:components/libseccomp.bst
- freedesktop-sdk.bst:components/libapparmor.bst
- freedesktop-sdk.bst:components/openssl.bst
# liblxc links libdbus-1.so (systemd scope/cgroup integration). dbus.bst is
# the convention used across the junctions (NetworkManager, libvirt, dconf...).
- freedesktop-sdk.bst:components/dbus.bst

variables:
  # Options validated against the v6.0.6 meson_options.txt + meson.build.
  # We build only liblxc.so + lxc.pc (all incus's go-lxc binding needs):
  #   tools/commands/examples/man off — no CLI binaries or docs.
  #   install-init-files + specfile off — skip lxc's own systemd units and the
  #   RPM spec; together these bypass the meson.build:155 block that otherwise
  #   demands `distrosysconfdir` (no /etc/default exists in the build sandbox).
  meson-local: >-
    -Dtests=false
    -Dexamples=false
    -Dman=false
    -Dtools=false
    -Dcommands=false
    -Dseccomp=true
    -Dapparmor=true
    -Dselinux=false
    -Dcapabilities=true
    -Dinstall-init-files=false
    -Dspecfile=false

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{libdir}/liblxc.so'

sources:
- kind: git_repo
  url: github:lxc/lxc.git
  track: v6.0.*
  exclude:
  - '*rc*'
  ref: v6.0.6-0-ge3a3f7066a01024bbf68319447ac7c6e5b20e94b
