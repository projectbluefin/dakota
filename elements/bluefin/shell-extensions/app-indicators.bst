kind: meson

sources:
- kind: git_repo
  url: github:ubuntu/gnome-shell-extension-appindicator.git
  track: v*
  ref: v64-0-gc934adc6c97363b8e6bb161ca8d1ac62d1da3d63

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/jq.bst

depends:
- freedesktop-sdk.bst:components/gettext.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""
