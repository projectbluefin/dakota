kind: compose

build-depends:
  - oci/layers/bluefin-stack.bst
  # The filtered toolchain survives the global devel filter without requiring
  # a second full-root composition.
  - oci/layers/brew-toolchain.bst

config:
  exclude:
    - devel
    - debug
    - static-blocklist
