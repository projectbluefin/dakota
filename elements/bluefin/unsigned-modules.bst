kind: manual

build-depends:
- core/sandbox-tools.bst
- filename: freedesktop-sdk.bst:components/linux.bst
  strict: true
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    mkdir -p "%{install-root}/usr/lib"
    cp -rT /usr/lib/modules "%{install-root}/usr/lib/modules"

  - |
    version="$(ls -1 /usr/lib/modules | head -n1)"
    cp /boot/vmlinuz "%{install-root}/usr/lib/modules/${version}"
