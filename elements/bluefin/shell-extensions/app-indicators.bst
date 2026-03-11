kind: meson

sources:
- kind: git_repo
  url: github:ubuntu/gnome-shell-extension-appindicator.git
  track: v*
  ref: v63-0-gbe68add0382b1ee19eb8e851464e3a3ac6900c6a

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/jq.bst

depends:
- freedesktop-sdk.bst:components/gettext.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""
