kind: meson

sources:
- kind: git_repo
  url: gnome:nautilus-python.git
  track: "master"
  ref: 4.1.0-4-gd777cdb431d56f09e4a1c1a747ab8b87673e3a92

variables:
  conf-flags: >-
    -Dgtk_doc=false

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/python3.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- gnome-build-meta.bst:core/nautilus.bst
- freedesktop-sdk.bst:components/pygobject.bst
