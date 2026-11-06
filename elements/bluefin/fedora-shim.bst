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
#
# Pin only builds Bodhi has pushed to a Fedora release (listed at
# https://bodhi.fedoraproject.org/updates/?packages=shim). Koji
# garbage-collects untagged builds, and a pinned build that disappears
# leaves publish unable to fetch the source. The standard build job in
# .github/workflows/build.yml also builds this element so its source and
# artifact stay in the project CAS, where the signing jobs pull it.
kind: manual

sources:
- kind: remote
  url: fedora_koji:shim/16.1/7/x86_64/shim-x64-16.1-7.x86_64.rpm
  ref: 0a119f3488e5da27ca55c1864ee8e131afa5ecf27689385ba09b805eb00dd608

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
    bsdtar -xf shim-x64-16.1-7.x86_64.rpm
    for f in shimx64.efi mmx64.efi; do
      install -Dm644 "usr/lib/efi/shim/16.1-7/EFI/fedora/$f" \
        "%{install-root}/usr/lib/dakota/secure-boot/$f"
    done
