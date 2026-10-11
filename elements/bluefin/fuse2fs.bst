kind: manual
description: |
  fuse2fs from the e2fsprogs version pinned by freedesktop-sdk. Built
  separately so the shared freedesktop-sdk e2fsprogs artifact is unchanged.

sources:
- kind: git_repo
  url: kernel:fs/ext2/e2fsprogs.git
  track: v*
  exclude:
  - v*rc*
  ref: v1.47.4-0-g7ee1d505ef3b37831215f490411f346fe57e9053

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/fuse3.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/e2fsprogs.bst
- freedesktop-sdk.bst:components/fuse3.bst
- freedesktop-sdk.bst:components/util-linux-libs.bst

config:
  configure-commands:
  - |
    ./configure --prefix=%{prefix} --libdir=%{libdir} --sysconfdir=%{sysconfdir} \
      --enable-elf-shlibs --enable-fuse2fs \
      --disable-libblkid --disable-libuuid --disable-fsck --disable-uuidd
  build-commands:
  - make -j${BST_BUILD_THREADS:-1} libs
  - make -j${BST_BUILD_THREADS:-1} -C misc fuse2fs fuse2fs.1
  install-commands:
  - install -Dm755 misc/fuse2fs "%{install-root}%{bindir}/fuse2fs"
  - install -Dm644 misc/fuse2fs.1 "%{install-root}%{mandir}/man1/fuse2fs.1"
