# Secure Boot pieces that exist only in signed images. bluefin/deps.bst
# pulls this in with `-o secure_boot_signing true`; the signed kernel image
# and modules replace the unsigned ones through the junction override in
# elements/gnome-build-meta.bst instead.
kind: stack

depends:
- bluefin/fedora-shim.bst
- bluefin/signed-efi.bst
- bluefin/secure-boot-tools.bst
- bluefin/lockdown-kargs.bst
