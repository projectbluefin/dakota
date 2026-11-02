kind: meson

sources:
- kind: git_repo
  url: kernel:utils/trace-cmd/trace-cmd.git
  track: trace-cmd-v*
  ref: trace-cmd-v3.4-0-g3ce20923b3efa60d417da7acc8a327615fbd1419

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/audit.bst
- freedesktop-sdk.bst:components/libtraceevent.bst
- freedesktop-sdk.bst:components/zlib.bst
- freedesktop-sdk.bst:components/zstd.bst
- bluefin/libtracefs.bst

variables:
  meson-local: >-
    -Ddoc=false
    -Dpython=false
    -Dutest=false
    -Dversion-tag=3.4

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{libdir}/libtracecmd.so'

config:
  install-commands:
    (>):
    - install -Dm644 LICENSES/GPL-2.0 "%{install-root}%{datadir}/licenses/trace-cmd/GPL-2.0"
    - install -Dm644 LICENSES/LGPL-2.1 "%{install-root}%{datadir}/licenses/trace-cmd/LGPL-2.1"
