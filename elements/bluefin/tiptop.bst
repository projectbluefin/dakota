kind: autotools

sources:
- kind: tar
  url: inria:pacap/tiptop/tiptop-2.3.2.tar.gz
  ref: a14b1b59ea4856844e27bc4e22129b7906b8815afaf50a25ac60998dafcc93a7

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
