kind: meson

sources:
- kind: git_repo
  url: gnome:nautilus-python.git
  track: "master"
  ref: 4.2.0-0-g17e7edf4d01bc43d0d550c5013d45659ac752cab

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
