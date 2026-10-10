kind: make

sources:
- kind: git_repo
  url: github:lm-sensors/lm-sensors.git
  track: V*
  ref: V3-6-2-0-g5c3ba50f806dea27c3b1e368966191c735459111

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
- freedesktop-sdk.bst:components/bison.bst
- freedesktop-sdk.bst:components/flex.bst
- freedesktop-sdk.bst:components/perl.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/perl.bst

variables:
  make-args: >-
    PREFIX=%{prefix}
    SBINDIR=%{bindir}
    BINDIR=%{bindir}
    LIBDIR=%{libdir}
    MANDIR=%{mandir}
    ETCDIR=%{sysconfdir}
    BUILD_STATIC_LIB=0
    user

config:
  install-commands:
  - |
    make -j1 install DESTDIR="%{install-root}" PREFIX="%{prefix}" SBINDIR="%{bindir}" BINDIR="%{bindir}" LIBDIR="%{libdir}" MANDIR="%{mandir}" ETCDIR="%{sysconfdir}"
  - |
    %{install-extra}
