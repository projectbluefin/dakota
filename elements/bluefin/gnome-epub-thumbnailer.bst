kind: meson

sources:
- kind: git_repo
  url: gnome:gnome-epub-thumbnailer.git
  track: '[0-9]*.[0-9]*'
  ref: 1.8-0-g64912a3a75a9dffd9db107d948336060837cc273

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst

depends:
- freedesktop-sdk.bst:components/libarchive.bst
- freedesktop-sdk.bst:components/libxml2.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- gnome-build-meta.bst:sdk/gdk-pixbuf.bst
- gnome-build-meta.bst:sdk/glib.bst
