kind: manual

sources:
- kind: tar
  url: sourceforge:nicstat/nicstat-1.95.tar.gz
  ref: c4cc33f8838f4523f27c3d7584eedbe59f4c587f0821612f5ac2201adc18b367
- kind: patch_queue
  path: patches/nicstat

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

config:
  build-commands:
  - gcc ${CFLAGS} ${CPPFLAGS} ${LDFLAGS} nicstat.c -o nicstat
  install-commands:
  - install -Dm755 nicstat "%{install-root}%{bindir}/nicstat"
  - install -Dm644 LICENSE.txt "%{install-root}%{datadir}/licenses/nicstat/LICENSE.txt"
  - '%{install-extra}'
