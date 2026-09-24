kind: meson

sources:
- kind: git_repo
  url: github:gsconnect/gnome-shell-extension-gsconnect.git
  track: v*
  ref: v73-0-gf68c95cb2985ba273129e9d4d9017f5b028c96d7
# v73 includes upstream PR #2192 (GNOME 51) except the OwnerChange signal
# declaration on the wl-clipboard fallback; DBus.wrapObject connects every
# interface signal. Drop once upstream declares it.
- kind: patch
  path: patches/gsconnect/0001-wl-clipboard-ownerchange.patch

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/desktop-file-utils.bst

depends:
- freedesktop-sdk.bst:components/gettext.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""
