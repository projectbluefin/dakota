kind: meson

sources:
- kind: git_repo
  url: gnome:nautilus-python.git
  track: "master"
  ref: 4.1.0-12-g89e40310a142966e2fede0d1e9f48413c719279c

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
