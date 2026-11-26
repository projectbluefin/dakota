# System info tool; common's ublue-fastfetch wrapper expects it on the image.
kind: cmake

sources:
- kind: git_repo
  url: github:fastfetch-cli/fastfetch.git
  track: "[0-9]*.[0-9]*.[0-9]*"
  ref: 2.71.0-0-g8c9d9c0449dd515e0088c4a60a38d2dc40c5ccd0

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst
# Headers enable wayland/drm/dbus features; the libs are dlopen'd at runtime.
- freedesktop-sdk.bst:components/wayland.bst
- freedesktop-sdk.bst:components/libdrm.bst
- freedesktop-sdk.bst:components/dbus.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
