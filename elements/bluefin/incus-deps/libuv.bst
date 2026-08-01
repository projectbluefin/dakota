# libuv — async I/O library.
# Foundation of the cowsql/raft replicated-DB stack that Incus links against.
# Not provided by freedesktop-sdk or gnome-build-meta, so we build it here.
kind: cmake

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  # Library only — no test/bench binaries, install the pkg-config file
  # (raft/cowsql discover libuv via `pkg-config libuv`).
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

sources:
- kind: git_repo
  url: github:libuv/libuv.git
  track: v*
  exclude:
  - '*rc*'
  ref: v1.52.1-0-g48dbd851fe4ad7d1252b75ac907c725a437e1634
