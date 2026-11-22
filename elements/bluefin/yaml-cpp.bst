kind: cmake

sources:
- kind: git_repo
  url: github:jbeder/yaml-cpp.git
  track: 'yaml-cpp-[0-9]*'
  ref: yaml-cpp-0.9.0-0-g56e3bb550c91fd7005566f19c079cb7a503223cf

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
