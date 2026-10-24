# Secure Boot pieces that exist only in signed images. The boot layer
# (oci/layers/boot-stack.bst) pulls this in with `-o secure_boot_signing
# true`; the signed kernel image and modules replace the unsigned ones
# through the junction override in elements/gnome-build-meta.bst instead.
# Every dependency here must stage only its own files: the boot layer may
# not carry base content, so secure-boot-tools comes through a filter that
# drops its runtime dependencies (the base image already has them).
kind: stack

depends:
- bluefin/fedora-shim.bst
- bluefin/signed-efi.bst
- bluefin/secure-boot-tools-files.bst
- bluefin/lockdown-kargs.bst
