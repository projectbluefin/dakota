# cowsql/raft is the Raft implementation expected by cowsql.
kind: autotools

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/pkg-config.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- bluefin/incus-deps/libuv.bst
- freedesktop-sdk.bst:components/lz4.bst

variables:
  conf-local: >-
    --enable-uv=yes
    --enable-example=no
    --enable-benchmark=no

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{libdir}/libraft.so'

config:
  install-commands:
    (>):
    - install -Dm644 LICENSE "%{install-root}%{datadir}/licenses/raft/LICENSE"

sources:
- kind: git_repo
  url: github:cowsql/raft.git
  track: v*
  exclude:
  - '*rc*'
  ref: v0.22.1-0-g9edb176a7924ce2b943cb56552366dc4b5a1a6b7
