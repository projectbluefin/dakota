# Chunkah ownership for the exact default compose artifact, without replaying it.
kind: chunkah-ownership

build-depends:
  - oci/layers/bluefin.bst
  - oci/layers/bluefin-stack.bst
  - oci/layers/brew-toolchain.bst
  - oci/chunkah/brew-toolchain.bst

config:
  layer-dependency: oci/layers/bluefin.bst
  provenance-dependencies:
    - oci/layers/bluefin-stack.bst
    - oci/layers/brew-toolchain.bst
  metadata-dependencies:
    - oci/chunkah/brew-toolchain.bst
  inherit-from-components:
    - oci/layers/brew-toolchain.bst
