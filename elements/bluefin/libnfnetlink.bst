kind: autotools

description: |
  libnfnetlink is the low-level library used by libnetfilter_queue to
  communicate with the kernel netfilter subsystem.

sources:
- kind: git_repo
  url: netfilter:libnfnetlink
  track: libnfnetlink-*
  ref: libnfnetlink-1.0.2-0-g8182d92e81a7feb54a6a27c3c1691a26c1aeda03

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/pkg-config.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  conf-local: >-
    --prefix=/usr
