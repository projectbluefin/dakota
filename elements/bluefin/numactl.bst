kind: autotools

sources:
- kind: tar
  url: github_files:numactl/numactl/releases/download/v2.0.19/numactl-2.0.19.tar.gz
  ref: f2672a0381cb59196e9c246bf8bcc43d5568bc457700a697f1a1df762b9af884

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

config:
  install-commands:
    (>):
    - rm -rf "%{install-root}%{mandir}"
    - install -Dm644 LICENSE.GPL2 "%{install-root}%{datadir}/licenses/numactl/LICENSE.GPL2"
    - install -Dm644 LICENSE.LGPL2.1 "%{install-root}%{datadir}/licenses/numactl/LICENSE.LGPL2.1"
