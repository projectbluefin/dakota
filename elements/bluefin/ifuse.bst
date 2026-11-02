kind: autotools
description: Mount iOS media and app document directories through FUSE.

sources:
- kind: tar
  url: github_files:libimobiledevice/ifuse/releases/download/1.2.1/ifuse-1.2.1.tar.bz2
  ref: 9d490470ba6553f8052b385bb5330462e46fbe82131ebe65be47a1cc1c70e857

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/fuse3.bst
- freedesktop-sdk.bst:components/openssl.bst
- gnome-build-meta.bst:core-deps/libplist.bst
- gnome-build-meta.bst:core-deps/libimobiledevice.bst

runtime-depends:
- bluefin/usbmuxd.bst
