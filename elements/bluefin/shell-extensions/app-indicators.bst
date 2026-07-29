kind: meson

sources:
- kind: git_repo
  url: github:ubuntu/gnome-shell-extension-appindicator.git
  track: v*
  ref: v65-0-gbd6775ad627117d8397d82403c650e753a5514c1

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/jq.bst

depends:
- freedesktop-sdk.bst:components/gettext.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""
