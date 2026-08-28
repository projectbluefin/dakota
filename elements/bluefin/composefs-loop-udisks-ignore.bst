kind: manual

sources:
  - kind: local
    path: files/udev

build-depends:
  - core/sandbox-tools.bst
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
    - install -Dm644 90-hide-composefs-loop.rules "%{install-root}/usr/lib/udev/rules.d/90-hide-composefs-loop.rules"
    - "%{install-extra}"
