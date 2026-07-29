kind: manual
description: lm-sensors userspace tools, including sensors-detect

sources:
- kind: git_repo
  url: github:lm-sensors/lm-sensors.git
  track: V3-6-2
  ref: V3-6-2-0-g5c3ba50f806dea27c3b1e368966191c735459111

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
- freedesktop-sdk.bst:components/bison.bst
- freedesktop-sdk.bst:components/flex.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/perl.bst

variables:
  strip-binaries: ""

config:
  build-commands:
  - make PREFIX="%{prefix}" BINDIR="%{bindir}" SBINDIR="%{bindir}"
  install-commands:
  - |
    make PREFIX="%{prefix}" BINDIR="%{bindir}" SBINDIR="%{bindir}" \
      DESTDIR="%{install-root}" user_install
    rm -rf "%{install-root}%{prefix}/include"
    rm -f "%{install-root}%{prefix}/lib/libsensors.a"
    rm -rf "%{install-root}%{prefix}/man/man3"
