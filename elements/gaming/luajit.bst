# LuaJIT runtime/development files for OGC gamescope's Lua scripting support.
# Freedesktop SDK 25.08 ships PUC Lua but not LuaJIT; gamescope's Meson build
# explicitly looks for the `luajit` pkg-config dependency.
kind: manual

sources:
# Upstream deleted the v2.1.ROLLING tag (and rewrote v2.1 history), so we
# track the rolling v2.1 branch and pin a bare commit; a bare sha ref fetches
# by commit and survives upstream ref churn.
- kind: git_repo
  url: github:LuaJIT/LuaJIT.git
  track: v2.1
  ref: 1edc3e52b67eaf6ce5f809be8e17d6862594b8bc # v2.1 tip, 2026-08-03

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

variables:
  strip-binaries: ''

config:
  # Install into multiarch %{libdir} so luajit.pc lands where this
  # project's pkg-config looks (cosmic compensates with a project-wide
  # PKG_CONFIG_PATH override; dakota has none, and gamescope's meson
  # needs the .pc).
  build-commands:
  - |
    multilib="%{libdir}"
    make PREFIX="%{prefix}" MULTILIB="${multilib#%{prefix}/}" BUILDMODE=dynamic
  install-commands:
  - |
    multilib="%{libdir}"
    make PREFIX="%{prefix}" MULTILIB="${multilib#%{prefix}/}" DESTDIR="%{install-root}" install
  - find "%{install-root}" -name '*.a' -delete

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{libdir}/libluajit-5.1.so'
