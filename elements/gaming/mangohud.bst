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
  url: github-releases:flightlessmango/MangoHud/releases/download/v0.8.3/MangoHud-0.8.3.r0.g330c42a.tar.gz
  ref: 620b6a635877dae2fecef2622c963eb3298b5fdccc90f9e1e71987b379a7f9e3

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
