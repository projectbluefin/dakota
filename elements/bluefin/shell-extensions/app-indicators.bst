kind: meson

sources:
- kind: git_repo
  url: github:ubuntu/gnome-shell-extension-appindicator.git
  track: v*
  ref: v66-0-g52da5222a17f7a862e8a47d2bc523f29abf59964

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/jq.bst

depends:
- freedesktop-sdk.bst:components/gettext.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""
