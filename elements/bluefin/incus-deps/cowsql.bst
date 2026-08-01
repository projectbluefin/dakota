# cowsql — embedded, replicated SQLite (the dqlite fork Incus uses).
# incusd links this via `pkg-config libcowsql` and the `libsqlite3` build tag
# (the Makefile probes for <cowsql.h>). Provides cowsql.pc.
kind: autotools

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/pkg-config.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- bluefin/incus-deps/libuv.bst
- bluefin/incus-deps/raft.bst
- freedesktop-sdk.bst:components/lz4.bst
- freedesktop-sdk.bst:components/sqlite.bst

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{libdir}/libcowsql.so'

sources:
- kind: git_repo
  url: github:cowsql/cowsql.git
  track: v*
  exclude:
  - '*rc*'
  ref: v1.15.9-0-g783815b901470e27b7dfbcce3a67c888dad19e78
