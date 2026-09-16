kind: manual
description: |
  libkrun process isolation library used by the krun OCI runtime.

sources:
- kind: git_repo
  url: github:libkrun/libkrun.git
  track: v1.19.0
  ref: v1.19.0-0-g9932c4b59d8f891e60c6aba20d22ebb99ceaa8e2

build-depends:
- freedesktop-sdk.bst:components/rust.bst
- freedesktop-sdk.bst:components/rust-src.bst
- freedesktop-sdk.bst:components/llvm.bst
- freedesktop-sdk.bst:components/openssl.bst
- freedesktop-sdk.bst:components/curl.bst
- freedesktop-sdk.bst:components/libcap-ng.bst
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ''

config:
  build-commands:
  - make BLK=1 NET=1 GPU=1 SND=1
  install-commands:
  - install -Dm755 libkrun.so.1.19.0 "%{install-root}%{libdir}/libkrun.so.1.19.0"
  - ln -s libkrun.so.1.19.0 "%{install-root}%{libdir}/libkrun.so.1"
  - ln -s libkrun.so.1 "%{install-root}%{libdir}/libkrun.so"
