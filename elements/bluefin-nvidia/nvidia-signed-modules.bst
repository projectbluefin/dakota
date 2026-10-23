# NVIDIA kernel modules signed with the Dakota Secure Boot key. Added to
# bluefin-nvidia/deps.bst only with `-o secure_boot_signing true`. It
# depends on nvidia-drivers.bst so it stages after it, and the signed copies
# replace the unsigned modules through the overlap whitelist. Signing in a
# separate element keeps the key out of nvidia-drivers.bst, so the driver
# build stays cached and shared with unsigned builds.
#
# Same isolation rule as bluefin/signed-modules.bst: never build this with
# push remotes or remote execution.
kind: manual

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:components/findutils.bst
- freedesktop-sdk.bst:components/openssl.bst
- freedesktop-sdk.bst:components/sign-file.bst
- freedesktop-sdk.bst:components/zstd.bst

depends:
- bluefin-nvidia/nvidia-drivers.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    mkdir -p "%{install-root}/usr/lib"
    cp -rT /usr/lib/modules "%{install-root}/usr/lib/modules"

  - |
    bash sign.sh modules "%{install-root}/usr/lib/modules"

public:
  bst:
    overlap-whitelist:
    - /usr/lib/modules/**

sources:
- kind: local
  path: files/boot-keys
