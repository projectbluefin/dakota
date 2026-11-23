# Everything files/live-iso/build.py runs. iso/live.bst builds with it, and
# `just iso <image>` opens it as a sandbox to build an ISO from an image that
# was exported or published outside BuildStream.
kind: stack

depends:
  - core/sandbox-tools.bst
  - freedesktop-sdk.bst:components/python3.bst
  - freedesktop-sdk.bst:components/glib.bst
  - freedesktop-sdk.bst:components/systemd.bst
  - iso/btrfs-progs.bst
  - freedesktop-sdk.bst:components/dosfstools.bst
  - freedesktop-sdk.bst:components/mtools.bst
  - freedesktop-sdk.bst:components/util-linux.bst
  - gnome-build-meta.bst:core-deps/dconf.bst
  - gnomeos-deps/bootc.bst
  - iso/live-tools.bst
  - iso/installer.bst
