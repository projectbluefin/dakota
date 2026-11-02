# Fedora's Microsoft-signed shim and MokManager, the first stage of Dakota's
# Secure Boot chain. Stock firmware only trusts Microsoft's keys; this shim
# is signed by both the Microsoft UEFI CA 2011 and 2023, and it trusts keys
# the user enrolls as a MOK, which is how the Dakota key becomes trusted.
# It launches grubx64.efi from its own directory, so dakota-secure-boot
# installs our signed systemd-boot under that name.
#
# The binaries are used exactly as Fedora signed them; any change would
# break the Microsoft signature. Pinned by checksum; bump to a newer Fedora
# build when shim releases or SBAT revocations require it.
kind: manual

sources:
- kind: remote
  url: fedora_koji:shim/16.1/9/x86_64/shim-x64-16.1-9.x86_64.rpm
  ref: eac405fe200847683e72b5bd7424727e034741b4c541f228e80d996c3a032478

build-depends:
- core/sandbox-tools.bst
# bsdtar reads the RPM; it links the bzip2 and xz libraries at runtime.
- freedesktop-sdk.bst:components/libarchive.bst
- freedesktop-sdk.bst:components/bzip2.bst
- freedesktop-sdk.bst:components/xz.bst
- freedesktop-sdk.bst:components/zstd.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    bsdtar -xf shim-x64-16.1-9.x86_64.rpm
    for f in shimx64.efi mmx64.efi; do
      install -Dm644 "usr/lib/efi/shim/16.1-9/EFI/fedora/$f" \
        "%{install-root}/usr/lib/dakota/secure-boot/$f"
    done
