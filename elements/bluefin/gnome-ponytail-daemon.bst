kind: meson

sources:
- kind: git_repo
  url: gnome_gitlab:ofourdan/gnome-ponytail-daemon.git
  track: "master"
  ref: 0.0.11-0-g72f222d912de8105208f6faa865b71480c189924

variables:
  conf-flags: >-
    -Dsystemd_user_unit_dir=/usr/lib/systemd/user

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/python3.bst
- freedesktop-sdk.bst:components/systemd.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/glib.bst
- freedesktop-sdk.bst:components/libei.bst
- freedesktop-sdk.bst:components/libxkbcommon.bst
