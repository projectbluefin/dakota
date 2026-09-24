# Xbox wireless-dongle firmware (Microsoft redistributable).
#
# Same payload Bazzite installs via xone-dongle-firmware / install/firmware.sh.
# Staged at build time so the runtime image carries no curl/bsdtar.
kind: manual

sources:
- kind: git
  url: github:OpenGamingCollective/xonedo
  track: master
  ref: 9e8a34e5f6a1d2c3b4a5f60718293a4b5c6d7e810

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:components/curl.bst
- freedesktop-sdk.bst:components/libarchive.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  build-commands:
  - bash install/firmware.sh --skip-disclaimer --destdir %{install-root}/usr/lib/firmware
  install-commands:
  - |
    %{install-extra}
