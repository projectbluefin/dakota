# System info tool; common's ublue-fastfetch wrapper expects it on the image.
kind: cmake

sources:
- kind: git_repo
  url: github:fastfetch-cli/fastfetch.git
  track: "[0-9]*.[0-9]*.[0-9]*"
  ref: 2.72.0-0-g27b8f8bb21f19241b7b68f79af49f35ad61f4edc

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst
# Headers enable wayland/drm/dbus features; the libs are dlopen'd at runtime.
- freedesktop-sdk.bst:components/wayland.bst
- freedesktop-sdk.bst:components/libdrm.bst
- freedesktop-sdk.bst:components/dbus.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
