kind: autotools

description: |
  libnetfilter_queue is the native C library used by OpenSnitch to receive
  packets from the kernel via nfqueue.

sources:
- kind: git_repo
  url: netfilter:libnetfilter_queue
  track: libnetfilter_queue-*
  ref: libnetfilter_queue-1.0.5-0-g2ff321690b8dafeca99ee8e9cafac71e36f292b9

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/pkg-config.bst

depends:
- freedesktop-sdk.bst:components/libmnl.bst
- bluefin/libnfnetlink.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  conf-local: >-
    --prefix=/usr
