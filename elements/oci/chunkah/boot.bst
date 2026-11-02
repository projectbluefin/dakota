# Chunkah ownership for the exact boot layer artifact. The thin final
# OCI element merges it with the base sidecar (ownership_metadata.py
# finalize-overlay); depmod output has no component and falls back to the
# integration owner.
kind: chunkah-ownership

build-depends:
  - oci/layers/boot.bst
  - oci/layers/boot-stack.bst

config:
  layer-dependency: oci/layers/boot.bst
  provenance-dependencies:
    - oci/layers/boot-stack.bst
