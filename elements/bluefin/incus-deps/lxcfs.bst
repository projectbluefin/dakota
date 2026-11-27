# lxcfs virtualizes /proc for system containers and supplies lxcfs.service.
kind: meson

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/pkg-config.bst
- freedesktop-sdk.bst:components/python3.bst
- freedesktop-sdk.bst:components/python3-jinja2.bst
- freedesktop-sdk.bst:components/systemd.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/fuse3.bst

variables:
  meson-local: >-
    -Dtests=false
    -Dinit-script=systemd
    -Ddocs=false

config:
  install-commands:
    (>):
    - install -Dm644 COPYING LICENSE.LGPL2.1 -t "%{install-root}%{datadir}/licenses/lxcfs"

sources:
- kind: git_repo
  url: github:lxc/lxcfs.git
  track: v6.0.*
  exclude:
  - '*rc*'
  ref: v6.0.6-0-gc2f02e7f78ab90de21a05cb3f953f110b0515500
