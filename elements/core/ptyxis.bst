kind: meson

sources:
- kind: git_repo
  url: gnome_gitlab:chergert/ptyxis.git
  track: "50.1"
  ref: 50.1-0-g0f045a653db114e22fe7bf4b409fcb30d7763fa9

build-depends:
- freedesktop-sdk.bst:components/desktop-file-utils.bst
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- gnome-build-meta.bst:sdk/blueprint-compiler.bst
- freedesktop-sdk.bst:components/itstool.bst

runtime-depends:
- gnome-build-meta.bst:sdk/adwaita-icon-theme.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- gnome-build-meta.bst:core-deps/libgtop.bst
- gnome-build-meta.bst:core-deps/libportal.bst
- gnome-build-meta.bst:core-deps/vte.bst
- gnome-build-meta.bst:core/nautilus.bst
- gnome-build-meta.bst:sdk/gtk.bst
- gnome-build-meta.bst:sdk/libadwaita.bst

variables:
  meson-local: >-
    -Dgeneric=terminal
