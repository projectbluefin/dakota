# Chunkah metadata for the exact filtered toolchain, preserving GCC/Make owners.
kind: chunkah-ownership

build-depends:
- oci/layers/brew-toolchain.bst
- freedesktop-sdk.bst:components/gcc.bst
- freedesktop-sdk.bst:components/make.bst

config:
  layer-dependency: oci/layers/brew-toolchain.bst
  provenance-dependencies:
  - components/gcc.bst
  - components/make.bst
