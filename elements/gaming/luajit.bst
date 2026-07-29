# LuaJIT runtime/development files for OGC gamescope's Lua scripting support.
# Freedesktop SDK 25.08 ships PUC Lua but not LuaJIT; gamescope's Meson build
# explicitly looks for the `luajit` pkg-config dependency.
kind: manual

sources:
- kind: git_repo
  url: github:LuaJIT/LuaJIT.git
  track: v2.1.ROLLING
  ref: v2.1.ROLLING-0-g2096ea625d78304e1955b4d7bfd5853cb547fba9

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
