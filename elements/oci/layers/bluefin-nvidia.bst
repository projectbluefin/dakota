kind: compose

build-depends:
  - oci/layers/bluefin-nvidia-stack.bst
  # The filtered toolchain survives the global devel filter without requiring
  # a second full-root composition.
  - oci/layers/brew-toolchain.bst

config:
  exclude:
    - devel
    - debug
    - static-blocklist
    # NVIDIA kernel modules ship in oci/layers/bluefin-nvidia-boot.bst.
    - kernel-modules
