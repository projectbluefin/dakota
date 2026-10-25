# The boot layer: oci/layers/boot-stack.bst plus the depmod output for the
# complete module set, checked by include/boot-layer.yml. Staged at
# /boot-set and copied out whole, so the artifact holds only boot files and
# no runtime dependencies.
kind: script

(@):
  - include/boot-layer.yml

build-depends:
  # Shell, coreutils and sed for the commands in include/boot-layer.yml;
  # runtime-minimal carries no shell since freedesktop-sdk 26.08.
  - core/sandbox-tools.bst
  - freedesktop-sdk.bst:components/sed.bst
  - freedesktop-sdk.bst:components/kmod.bst
  - freedesktop-sdk.bst:components/openssl.bst
  - freedesktop-sdk.bst:components/findutils.bst
  - filename: oci/layers/boot-stack.bst
    config:
      location: /boot-set

(?):
- secure_boot_signing == true:
    build-depends:
      (>):
      - freedesktop-sdk.bst:components/sbsigntools-maybe.bst
