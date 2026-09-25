kind: cmake

sources:
- kind: git_repo
  url: github:rime/ibus-rime.git
  ref: 3c73b2cf80685e75ed42c7631790936fb4f6b4b2

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- bluefin/librime.bst
- gnome-build-meta.bst:core-deps/ibus-daemon.bst
- gnome-build-meta.bst:sdk/libnotify.bst

variables:
  cmake-local: >-
    -DRIME_DATA_DIR=%{datadir}/rime-data

config:
  install-commands:
    (>):
    # Input schemes, dictionaries and frontend configuration are user-managed.
    - rm %{install-root}%{datadir}/rime-data/ibus_rime.yaml
    - rmdir %{install-root}%{datadir}/rime-data
    - install -Dm644 LICENSE %{install-root}%{datadir}/licenses/ibus-rime/LICENSE
