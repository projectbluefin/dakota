kind: manual
description: Nethogs network bandwidth monitor

sources:
- kind: git_repo
  url: github:raboof/nethogs.git
  track: v0.9.0
  ref: v0.9.0-0-g2d5e96c5af8edc9dbdfa61ca71464f636a2af291

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
- gnome-build-meta.bst:core-deps/libpcap.bst
- freedesktop-sdk.bst:bootstrap/ncurses.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- gnome-build-meta.bst:core-deps/libpcap.bst
- freedesktop-sdk.bst:bootstrap/ncurses.bst

variables:
  strip-binaries: ""

config:
  build-commands:
  - make VERSION=0.9.0 NCURSES_LIBS="-lncurses -ltinfo" CXXFLAGS="-Wall -Wextra -Wno-missing-field-initializers -std=c++14"
  install-commands:
  - make VERSION=0.9.0 NCURSES_LIBS="-lncurses -ltinfo" sbin="%{bindir}" DESTDIR="%{install-root}" install
