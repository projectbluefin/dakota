kind: manual
description: |
  crun built with libkrun support. The krun symlink is the OCI runtime name
  consumed by Bluefin Review.

sources:
- kind: git_repo
  url: github:containers/crun.git
  track: 1.28
  ref: 1.28-0-g54f16ffbefcd022bf032af768b5c5ce075c18bfc

build-depends:
- freedesktop-sdk.bst:components/autoconf.bst
- freedesktop-sdk.bst:components/automake.bst
- freedesktop-sdk.bst:components/libtool.bst
- freedesktop-sdk.bst:components/python3.bst
- freedesktop-sdk.bst:components/gperf.bst
- freedesktop-sdk.bst:components/pkg-config.bst
- bluefin/libkrun.bst

depends:
- bluefin/libkrun.bst
- freedesktop-sdk.bst:components/libseccomp.bst
- freedesktop-sdk.bst:components/libcap.bst
- freedesktop-sdk.bst:components/systemd-libs.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ''

config:
  configure-commands:
  - ./autogen.sh
  - ./configure --with-libkrun --enable-embedded-yajl
  build-commands:
  - make -j${BST_BUILD_THREADS}
  install-commands:
  - install -Dm755 crun "%{install-root}%{bindir}/crun-krun"
  - ln -s crun-krun "%{install-root}%{bindir}/krun"
