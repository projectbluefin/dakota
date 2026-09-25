kind: cmake

sources:
- kind: git_repo
  url: github:BYVoid/OpenCC.git
  ref: 025f371dc76b598d77384fbdab90c937471844d8 # ver.1.4.2

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst
- freedesktop-sdk.bst:components/python3.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- bluefin/marisa-trie.bst

variables:
  cmake-local: >-
    -DUSE_SYSTEM_MARISA=ON
    -DLIB_INSTALL_DIR=%{libdir}
    -DENABLE_GTEST=OFF
    -DBUILD_DOCUMENTATION=OFF

config:
  install-commands:
    (>):
    - install -Dm644 LICENSE %{install-root}%{datadir}/licenses/opencc/LICENSE
