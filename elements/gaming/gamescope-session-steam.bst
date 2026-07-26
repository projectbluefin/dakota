# OpenGamingCollective Steam Big Picture gamescope session.
#
# Ships the Steam session definition and helper shims used by SteamOS-style
# game mode. Native gamescope and native /usr/bin/steam are provided by the
# host gaming stack.
kind: manual

sources:
- kind: git_repo
  url: github:OpenGamingCollective/gamescope-session-steam.git
  track: main
  ref: 1019f9a2a98b7aaa180c3739901244854b126787

build-depends:
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/coreutils.bst
- freedesktop-sdk.bst:components/sed.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:components/python3.bst
- freedesktop-sdk.bst:components/polkit.bst
- freedesktop-sdk.bst:components/tar.bst
- gaming/gamescope-session.bst
- gaming/steam-native.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - mkdir -p "%{install-root}/usr"
  - cp -a usr/. "%{install-root}/usr/"
  - |
    desktop="%{install-root}/usr/share/wayland-sessions/gamescope-session-steam.desktop"
    if ! grep -q '^TryExec=' "$desktop"; then
      sed -i '/^Exec=/a TryExec=/usr/bin/gamescope' "$desktop"
    fi
