kind: manual

sources:
  - kind: local
    path: files/sysusers

build-depends:
  - core/sandbox-tools.bst
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
    - install -Dm644 bluefin-udev-groups.conf "%{install-root}/usr/lib/sysusers.d/bluefin-udev-groups.conf"
    - "%{install-extra}"
