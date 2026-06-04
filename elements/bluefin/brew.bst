kind: manual

sources:
- kind: git_repo
  url: github:ublue-os/brew.git
  track: main
  ref: 55f0e7542856b6e2e8703212b3e5d5d02f9b864f

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - cp -r system_files/usr/ "%{install-root}%{prefix}/"
  - cp -r system_files/etc/ "%{install-root}%{sysconfdir}/"
  - "%{install-extra}"
