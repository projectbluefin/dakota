kind: cmake

sources:
- kind: git_repo
  url: github:s-yata/marisa-trie.git
  ref: 3e87d53b78e15f2f43783d5e376561a8c9722051

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  cmake-local: >-
    -DBUILD_SHARED_LIBS=ON
    -DCMAKE_BUILD_TYPE=Release
    -DLIB_INSTALL_DIR=%{libdir}
    -DBUILD_TESTING=OFF
    -DENABLE_NATIVE_CODE=OFF

config:
  install-commands:
    (>):
    - install -Dm644 COPYING.md %{install-root}%{datadir}/licenses/marisa-trie/COPYING.md
