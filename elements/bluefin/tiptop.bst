kind: autotools

sources:
# Upstream tags no releases and its tarball host blocks listing, so follow the
# repository; it commits configure and the generated parser, as the tarball had.
- kind: git_repo
  url: inria_gitlab:rohou/tiptop.git
  track: master
  ref: e91f7d6099c1f97f6492237cad7addea591b530b

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:bootstrap/ncurses.bst
- freedesktop-sdk.bst:components/libxml2.bst

variables:
  # tiptop's Makefile.in passes @srcdir@ to VPATH, which fails when srcdir != .
  # because src/Makefile.in uses relative -I.. and pregenerated y.tab.c/lex.yy.c.
  build-dir: .
  # ncurses in freedesktop-sdk splits low-level terminfo symbols (cbreak, etc.)
  # into libtinfo.so.6. Passing LIBS=-ltinfo via conf-local satisfies ld.
  conf-local: >-
    LIBS=-ltinfo

config:
  install-commands:
    (>):
    # src/Makefile.in creates a hard link `ln tiptop ptiptop`. freedesktop-sdk-stripper
    # rejects binaries with multiple hard links ("Multiple links!"). Convert ptiptop
    # to a relative symbolic link so stripper succeeds.
    - rm -f "%{install-root}%{bindir}/ptiptop"
    - ln -s tiptop "%{install-root}%{bindir}/ptiptop"
    - rm -rf "%{install-root}%{mandir}"
    - install -Dm644 COPYING "%{install-root}%{datadir}/licenses/tiptop/COPYING"
