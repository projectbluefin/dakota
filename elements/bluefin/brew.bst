kind: manual

sources:
- kind: git_repo
  url: github:ublue-os/brew.git
  track: main
  ref: df2b153f29a75ed4d3b597e2243823ed855aa26e

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - cp -r system_files/usr/ "%{install-root}%{prefix}/"
  - cp -r system_files/etc/ "%{install-root}%{sysconfdir}/"
  - "%{install-extra}"
