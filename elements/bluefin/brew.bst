kind: manual

build-depends:
- core/sandbox-tools.bst

sources:
- kind: git_repo
  url: github:ublue-os/brew.git
  track: main
  ref: 373e0ac907ba33269522e37fd38f45894f1bd984

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - cp -r system_files/usr/ "%{install-root}%{prefix}/"
  - cp -r system_files/etc/ "%{install-root}%{sysconfdir}/"
  - "%{install-extra}"
