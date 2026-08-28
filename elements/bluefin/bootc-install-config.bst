kind: manual

sources:
- kind: local
  path: files/bootc-install

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm644 00-defaults.toml "%{install-root}/usr/lib/bootc/install/00-defaults.toml"
  - "%{install-extra}"
