kind: manual
description: |
  crun built with libkrun support. The krun symlink is the OCI runtime name
  consumed by projectbluefin/contribute. Sources mirror the pinned
  freedesktop-sdk crun element.

sources:
- kind: git_repo
  url: github:containers/crun.git
  track: '*.*'
  ref: 1.29.1-0-gf0d911de5587342cfeb16473bf32ecdfeaf25957
- kind: git_module
  path: libocispec
  url: github:containers/libocispec.git
  ref: 872b8b0b7ccb1a121601ede0dcac8c6b8a1008a6
- kind: git_module
  path: runtime-spec
  url: github:opencontainers/runtime-spec.git
  directory: libocispec
  ref: d64c1d945da7cf6970061c7c9ff4391fafdf2a15
- kind: git_module
  path: image-spec
  url: github:opencontainers/image-spec.git
  directory: libocispec
  ref: 26647a49f642c7d22a1cd3aa0a48e4650a542269

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/_private/git-minimal.bst
- freedesktop-sdk.bst:components/gperf.bst
- freedesktop-sdk.bst:components/python3.bst

depends:
- bluefin/libkrun.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/json-c.bst
- freedesktop-sdk.bst:components/libcap.bst
- freedesktop-sdk.bst:components/libseccomp.bst
- freedesktop-sdk.bst:components/systemd-libs.bst

variables:
  strip-binaries: ''

config:
  configure-commands:
  - ./autogen.sh
  - ./configure --prefix=%{prefix} --libdir=%{libdir} --sysconfdir=%{sysconfdir} --with-libkrun
  build-commands:
  - make -j${BST_BUILD_THREADS:-1}
  install-commands:
  - install -Dm755 crun "%{install-root}%{bindir}/crun-krun"
  - ln -s crun-krun "%{install-root}%{bindir}/krun"
