# Everything in the image that changes with secure_boot_signing: the kernel
# image and modules (signed or unsigned through the junction override in
# elements/gnome-build-meta.bst), the initramfs, and in signed images the
# Secure Boot pieces. It ships as a separate top layer, so the base image
# below it has the same cache key with and without signing and publish can
# pull it from the cache instead of rebuilding it.
#
# Every dependency must stage only its own files (no runtime dependencies
# that the base also contains); ownership_metadata.py finalize-overlay
# rejects a boot layer that touches paths outside its allowed prefixes.
kind: stack

depends:
  - gnome-build-meta.bst:gnomeos/initramfs/signed-modules.bst
  - gnome-build-meta.bst:oci/initramfs/image.bst

(?):
- secure_boot_signing == true:
    depends:
      (>):
      - bluefin/secure-boot.bst
