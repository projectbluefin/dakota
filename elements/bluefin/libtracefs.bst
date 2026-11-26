kind: meson
description: |
  Library for accessing the kernel tracefs filesystem. Required by powertop
  (>= 2.16) and trace-cmd; freedesktop-sdk ships libtraceevent but not libtracefs.

sources:
- kind: git_repo
  url: kernel:libs/libtrace/libtracefs.git
  track: libtracefs-*
  ref: libtracefs-1.8.4-0-g85030efcf90a775f07453d7eab835681c0ad7187

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/bison.bst
- freedesktop-sdk.bst:components/flex.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/libtraceevent.bst

variables:
  meson-local: >-
    -Ddoc=false
    -Dsamples=false
    -Dutest=false

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{libdir}/libtracefs.so'

config:
  install-commands:
    (>):
    - install -Dm644 LICENSES/LGPL-2.1 "%{install-root}%{datadir}/licenses/libtracefs/LGPL-2.1"
