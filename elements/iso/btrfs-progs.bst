# btrfs-progs for building the live ISO only. The image keeps
# freedesktop-sdk's components/btrfs-progs.bst.
#
# It is the freedesktop-sdk element at a newer release, because 7.3 is the
# first whose `mkfs.btrfs --rootdir` gives the same filesystem for the same
# input (sorted directory walk, SOURCE_DATE_EPOCH, UUIDs derived from the
# filesystem UUID), plus one patch that makes `--shrink` drop empty block
# groups, which takes about 2.9 GiB of unused space out of the ISO.
#
# Use freedesktop-sdk's element again once it carries a release with both.
kind: autotools

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/asciidoc.bst
- freedesktop-sdk.bst:components/docbook-xsl.bst
- freedesktop-sdk.bst:components/libxslt.bst
- freedesktop-sdk.bst:components/python3-setuptools.bst
- freedesktop-sdk.bst:components/python3-sphinx-rtd-theme.bst
- freedesktop-sdk.bst:components/python3-sphinx.bst
- freedesktop-sdk.bst:components/xmlto.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/e2fsprogs.bst
- freedesktop-sdk.bst:components/lzo.bst
- freedesktop-sdk.bst:components/systemd-libs.bst
- freedesktop-sdk.bst:components/zstd.bst

variables:
  # Makefile not generated inside build-dir
  build-dir: ''

sources:
- kind: git_repo
  url: kernel:linux/kernel/git/kdave/btrfs-progs.git
  ref: v7.3-0-gafdc3a65e33f4d42f768ad50dca20c32e5ee1496
- kind: patch_queue
  path: patches/btrfs-progs
