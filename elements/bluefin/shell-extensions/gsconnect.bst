kind: meson

sources:
- kind: git_repo
  url: github:gsconnect/gnome-shell-extension-gsconnect.git
  track: v*
  ref: v74-0-g61cc76b966f95a19d396fe0fc42a755fcb902bd4

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/desktop-file-utils.bst

depends:
- freedesktop-sdk.bst:components/gettext.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""
