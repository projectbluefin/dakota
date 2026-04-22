kind: manual

sources:
- kind: git_repo
  url: github:ublue-os/brew.git
  track: main
  ref: 498094cec1c13bb1f376a753e66a47f15e4f3458

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - cp -r system_files/usr/ "%{install-root}%{prefix}/"
  - cp -r system_files/etc/ "%{install-root}%{sysconfdir}/"
  - "%{install-extra}"
