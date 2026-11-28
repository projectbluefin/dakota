# Native MangoHud overlay from upstream's release package.
#
# Bazzite ships MangoHud on the host so native launchers, gamescope-session,
# and Steam's mangoapp integration have the Vulkan layer and `mangohud` helper
# immediately available. Upstream's release tarball contains a ready-made
# /usr payload for x86_64 + i686; installing that avoids vendoring MangoHud's
# wrapdb/subproject forest here.
kind: manual

sources:
- kind: tar
  url: github-releases:flightlessmango/MangoHud/releases/download/v0.8.4/MangoHud-0.8.4.r0.g992103e.tar.gz
  ref: aa0b2a009552f5e7c50baabf361267a79ea5e5c0fea440786f3b202d51f57753

build-depends:
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/coreutils.bst
- freedesktop-sdk.bst:components/tar.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/vulkan-icd-loader.bst
- freedesktop-sdk.bst:components/dbus.bst
- freedesktop-sdk.bst:components/wayland.bst
- freedesktop-sdk.bst:components/libxkbcommon.bst
- freedesktop-sdk.bst:components/xorg-lib-x11.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - mkdir -p "%{install-root}"
  - tar -xf MangoHud-package.tar -C "%{install-root}"
  # Keep runtime payload only
  - rm -f "%{install-root}/usr/lib/mangohud/lib32/libimgui.a" "%{install-root}/usr/lib/mangohud/lib64/libimgui.a"
