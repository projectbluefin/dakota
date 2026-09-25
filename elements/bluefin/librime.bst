kind: cmake

sources:
- kind: git_repo
  url: github:rime/librime.git
  ref: 33e78140250125871856cdc5b42ddc6a5fcd3cd4
- kind: git_repo
  url: github:hchunhui/librime-lua.git
  ref: ad1e4a6c98abf634dd34242a747f9b1d5d069fbe
  directory: plugins/lua

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst
- bluefin/boost.bst
- freedesktop-sdk.bst:components/xorg-proto-xorgproto.bst
- freedesktop-sdk.bst:components/lua.bst
- freedesktop-sdk.bst:components/sed.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- bluefin/glog.bst
- bluefin/leveldb.bst
- bluefin/marisa-trie.bst
- bluefin/yaml-cpp.bst
- bluefin/opencc.bst

variables:
  cmake-local: >-
    -DBUILD_TEST=OFF
    -DBUILD_DATA=OFF
    -DENABLE_TIMESTAMP=OFF
    -DBUILD_MERGED_PLUGINS=ON

environment:
  PKG_CONFIG_PATH: '%{build-root}/pkgconfig'

config:
  configure-commands:
    (<):
    # The SDK Lua pkg-config file includes its installation staging prefix.
    - mkdir -p pkgconfig
    - sed 's|/buildstream-install||g' %{libdir}/pkgconfig/lua.pc > pkgconfig/lua.pc
  install-commands:
    (>):
    - install -Dm644 LICENSE %{install-root}%{datadir}/licenses/librime/LICENSE
    - install -Dm644 plugins/lua/LICENSE %{install-root}%{datadir}/licenses/librime-lua/LICENSE
    # The SDK provides static Lua; its header contains the full MIT notice.
    - install -Dm644 %{includedir}/lua.h %{install-root}%{datadir}/licenses/lua/lua.h
