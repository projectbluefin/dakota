# The live ISO: boots the image's own kernel into a live session whose root
# is a btrfs seed laid out like a bootc composefs install, and installs by
# moving that running filesystem onto the target disk. See
# files/live-iso/build.py.
#
# It is built from oci/bluefin.bst, so with secure_boot_signing it carries
# the signed boot chain and must be built where the key is.
kind: script

build-depends:
  - iso/tools.bst
  - filename: oci/bluefin.bst
    config:
      location: /image

config:
  commands:
    - |
      mkdir -p /build /var/tmp
      WORK=/build python3 "%{libexecdir}/dakota-live-iso/build.py" /image "%{install-root}"
