kind: cmake

sources:
- kind: git_repo
  url: github:google/leveldb.git
  ref: 99b3c03b3284f5886f9ef9a4ef703d57373e61be

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  cmake-local: >-
    -DBUILD_SHARED_LIBS=ON
    -DLEVELDB_BUILD_TESTS=OFF
    -DLEVELDB_BUILD_BENCHMARKS=OFF

config:
  install-commands:
    (>):
    - install -Dm644 LICENSE %{install-root}%{datadir}/licenses/leveldb/LICENSE
