# lxcfs — FUSE filesystem giving containers a virtualized, cgroup-aware
# /proc (cpuinfo, meminfo, uptime, ...). Incus mounts this into system
# containers. Ships its own lxcfs.service.
kind: meson

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/pkg-config.bst
# lxcfs meson unconditionally templates headers/units via jinja2 at configure
# (meson.build:20 `import jinja2`), independent of -Ddocs/-Dtests.
- freedesktop-sdk.bst:components/python3.bst
- freedesktop-sdk.bst:components/python3-jinja2.bst
# init-script=systemd queries `pkg-config systemd` for systemdsystemunitdir to
# place lxcfs.service (config/init/meson.build:4). Same dep qrtr/libfprint/snapd
# use for the unit dir.
- freedesktop-sdk.bst:components/systemd.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/fuse3.bst

variables:
  # Options validated against the v6.0.6 meson_options.txt.
  meson-local: >-
    -Dtests=false
    -Dinit-script=systemd
    -Ddocs=false

sources:
- kind: git_repo
  url: github:lxc/lxcfs.git
  track: v6.0.*
  exclude:
  - '*rc*'
  ref: v6.0.6-0-gc2f02e7f78ab90de21a05cb3f953f110b0515500
