kind: cmake

sources:
- kind: git_repo
  url: github:jbeder/yaml-cpp.git
  ref: 2f86d13775d119edbb69af52e5f566fd65c6953b

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  cmake-local: >-
    -DYAML_BUILD_SHARED_LIBS=ON
    -DYAML_CPP_BUILD_TESTS=OFF
    -DYAML_CPP_BUILD_TOOLS=OFF

config:
  install-commands:
    (>):
    - install -Dm644 LICENSE %{install-root}%{datadir}/licenses/yaml-cpp/LICENSE
