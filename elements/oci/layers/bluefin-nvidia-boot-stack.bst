# The default boot set plus the NVIDIA kernel modules, signed in signed
# images. See oci/layers/boot-stack.bst.
kind: stack

depends:
  - oci/layers/boot-stack.bst
  - bluefin-nvidia/nvidia-kernel-modules.bst

(?):
- secure_boot_signing == true:
    depends:
      (>):
      - bluefin-nvidia/nvidia-signed-modules.bst
