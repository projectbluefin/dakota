# The NVIDIA boot layer: oci/layers/bluefin-nvidia-boot-stack.bst plus the
# depmod output for the kernel and NVIDIA modules together, checked by
# include/boot-layer.yml. Staged at /boot-set and copied out whole, so the
# artifact holds only boot files and no runtime dependencies.
kind: script

(@):
  - include/boot-layer.yml

build-depends:
  - freedesktop-sdk.bst:components/kmod.bst
  - freedesktop-sdk.bst:components/openssl.bst
  - freedesktop-sdk.bst:components/findutils.bst
  - filename: oci/layers/bluefin-nvidia-boot-stack.bst
    config:
      location: /boot-set

(?):
- secure_boot_signing == true:
    build-depends:
      (>):
      - freedesktop-sdk.bst:components/sbsigntools-maybe.bst
