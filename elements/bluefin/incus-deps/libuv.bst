# libuv backs the cowsql/raft stack linked by incusd.
kind: cmake

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  cmake-local: >-
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_SHARED_LIBS=ON
    -DLIBUV_BUILD_TESTS=OFF
    -DLIBUV_BUILD_BENCH=OFF

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{libdir}/libuv.so'

config:
  install-commands:
    (>):
    - install -Dm644 LICENSE "%{install-root}%{datadir}/licenses/libuv/LICENSE"

sources:
- kind: git_repo
  url: github:libuv/libuv.git
  track: v*
  exclude:
  - '*rc*'
  ref: v1.52.1-0-g48dbd851fe4ad7d1252b75ac907c725a437e1634
