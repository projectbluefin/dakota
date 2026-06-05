kind: meson

sources:
- kind: git_repo
  url: gnome:nautilus-python.git
  track: "master"
  ref: 4.1.0-0-g52fe5a0339065aa5461075c53002b1534b590188

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
