kind: manual
description: |
  gocryptfs userspace encrypted filesystem used by Bluefin Review.

sources:
- kind: git_repo
  url: github:rfjakob/gocryptfs.git
  track: v2.6.1
  ref: v2.6.1-0-g25e85a4454e93643ad92397d01ed532a360d7ee2

build-depends:
- freedesktop-sdk.bst:components/go.bst
- freedesktop-sdk.bst:components/openssl.bst
- freedesktop-sdk.bst:components/fuse3.bst

depends:
- freedesktop-sdk.bst:components/fuse3.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

environment:
  GOTOOLCHAIN: local
  GOPROXY: off
  GOFLAGS: -trimpath -buildvcs=false

variables:
  strip-binaries: ''

config:
  build-commands:
  - ./build.bash
  install-commands:
  - install -Dm755 gocryptfs "%{install-root}%{bindir}/gocryptfs"
  - install -Dm755 gocryptfs-xray/gocryptfs-xray "%{install-root}%{bindir}/gocryptfs-xray"
