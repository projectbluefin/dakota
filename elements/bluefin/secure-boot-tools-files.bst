# bluefin/secure-boot-tools.bst without its runtime dependencies, for the
# boot layer, which may only carry its own files. The base image already
# provides what the tools need at runtime (runtime-minimal and efibootmgr).
kind: filter

build-depends:
- bluefin/secure-boot-tools.bst

config:
  include-orphans: true
