# Kernel image and modules signed with the Dakota Secure Boot key.
# Replaces bluefin/unsigned-modules.bst when built with
# `-o secure_boot_signing true` (see elements/gnome-build-meta.bst). The
# signed vmlinuz is what bootc copies into the boot entry, so shim and
# systemd-boot can verify it once the key is enrolled as a MOK.
#
# The private key is a local source (files/boot-keys/private/secure-boot.key).
# Build this only with no push remotes and no remote execution: pushed
# sources, a failed build's cached buildtree, or remote execution inputs
# would all upload the key to the CAS. Publish and the pr-image job run it
# as a local pass after pulling everything else from the cache.
kind: manual

build-depends:
- core/sandbox-tools.bst
- filename: bluefin/unsigned-modules.bst
  strict: true
- freedesktop-sdk.bst:components/findutils.bst
- freedesktop-sdk.bst:components/openssl.bst
- freedesktop-sdk.bst:components/sbsigntools-maybe.bst
- freedesktop-sdk.bst:components/sign-file.bst
- freedesktop-sdk.bst:components/zstd.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    mkdir -p "%{install-root}/usr/lib"
    cp -rT /usr/lib/modules "%{install-root}/usr/lib/modules"

  - |
    bash sign.sh modules "%{install-root}/usr/lib/modules"

  - |
    version="$(ls -1 /usr/lib/modules | head -n1)"
    bash sign.sh efi "/usr/lib/modules/${version}/vmlinuz" \
      "%{install-root}/usr/lib/modules/${version}/vmlinuz"

sources:
- kind: local
  path: files/boot-keys
