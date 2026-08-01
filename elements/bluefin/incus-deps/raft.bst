# cowsql/raft — Raft consensus implementation used by cowsql.
# This is the cowsql fork of canonical/raft (the API cowsql expects), NOT
# canonical's raft. Provides raft.pc for cowsql to link against.
kind: autotools

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/pkg-config.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- bluefin/incus-deps/libuv.bst
- freedesktop-sdk.bst:components/lz4.bst

variables:
  # VALIDATE: confirm flag names against the v0.22.x configure.ac.
  # libuv backend is required for cowsql; example/benchmark binaries are not.
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

sources:
- kind: git_repo
  url: github:cowsql/raft.git
  track: v*
  exclude:
  - '*rc*'
  ref: v0.22.1-0-g9edb176a7924ce2b943cb56552366dc4b5a1a6b7
