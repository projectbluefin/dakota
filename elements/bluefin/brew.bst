kind: manual

build-depends:
- core/sandbox-tools.bst

sources:
- kind: git_repo
  url: github:ublue-os/brew.git
  track: main
  ref: 550a03e3d5f600282c8b4c73060bb830c91c1f74

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - cp -r system_files/usr/ "%{install-root}%{prefix}/"
  - cp -r system_files/etc/ "%{install-root}%{sysconfdir}/"
  - "%{install-extra}"
