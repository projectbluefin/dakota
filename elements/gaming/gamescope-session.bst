# OpenGamingCollective gamescope-session-plus common session scaffolding.
#
# This is the OGC/ChimeraOS layer Bazzite uses for console/handheld-style
# sessions. It provides the common launcher, systemd user target/service,
# gamescope scripts, GPU selector helper, and session configuration search path.
kind: manual

sources:
- kind: git_repo
  url: github:OpenGamingCollective/gamescope-session.git
  track: main
  ref: b5c2d0d3ebcefa7450d9d4336dd5802aa96d8513

build-depends:
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/coreutils.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/systemd.bst
- freedesktop-sdk.bst:components/dbus-tools.bst
- freedesktop-sdk.bst:components/pciutils.bst
- freedesktop-sdk.bst:components/util-linux.bst
- gaming/mangohud.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - mkdir -p "%{install-root}/usr"
  - cp -a usr/. "%{install-root}/usr/"
