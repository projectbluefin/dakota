kind: cmake

sources:
- kind: git_repo
  url: github:google/glog.git
  ref: 7b134a5c82c0c0b5698bb6bf7a835b230c5638e4

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  cmake-local: >-
    -DBUILD_TESTING=OFF
    -DWITH_GFLAGS=OFF
    -DWITH_UNWIND=OFF

config:
  install-commands:
    (>):
    - install -Dm644 COPYING %{install-root}%{datadir}/licenses/glog/COPYING
