# Chunkah ownership for the exact NVIDIA compose artifact, without replaying it.
kind: chunkah-ownership

build-depends:
  - oci/layers/bluefin-nvidia.bst
  - oci/layers/bluefin-nvidia-stack.bst
  - oci/layers/brew-toolchain.bst
  - oci/chunkah/brew-toolchain.bst

config:
  layer-dependency: oci/layers/bluefin-nvidia.bst
  provenance-dependencies:
    - oci/layers/bluefin-nvidia-stack.bst
    - oci/layers/brew-toolchain.bst
  metadata-dependencies:
    - oci/chunkah/brew-toolchain.bst
  inherit-from-components:
    - oci/layers/brew-toolchain.bst
