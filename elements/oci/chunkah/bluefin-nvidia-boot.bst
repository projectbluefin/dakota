# Chunkah ownership for the exact NVIDIA boot layer artifact. The thin final
# OCI element merges it with the base sidecar (ownership_metadata.py
# finalize-overlay); depmod output has no component and falls back to the
# integration owner.
kind: chunkah-ownership

build-depends:
  - oci/layers/bluefin-nvidia-boot.bst
  - oci/layers/bluefin-nvidia-boot-stack.bst

config:
  layer-dependency: oci/layers/bluefin-nvidia-boot.bst
  provenance-dependencies:
    - oci/layers/bluefin-nvidia-boot-stack.bst
