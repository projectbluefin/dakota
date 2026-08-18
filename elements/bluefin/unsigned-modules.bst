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
    # 25.08 kernels install vmlinuz to /boot; 26.08 kernels ship it inside
    # /usr/lib/modules/<ver>/ already. Handle both, then prove it's there.
    version="$(ls -1 /usr/lib/modules | head -n1)"
    if [ -f /boot/vmlinuz ]; then
      cp /boot/vmlinuz "%{install-root}/usr/lib/modules/${version}"
    fi
    test -f "%{install-root}/usr/lib/modules/${version}/vmlinuz"
