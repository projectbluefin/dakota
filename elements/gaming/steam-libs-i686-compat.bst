# Small compatibility symlinks for Debian/Ubuntu-style SONAMEs expected by
# Valve's 32-bit Steam client packages.
kind: manual

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/coreutils.bst

variables:
  # Symlinks only; the fdsdk stripper isn't staged in this sandbox.
  strip-binaries: ''

config:
  install-commands:
  - |
    mkdir -p "%{install-root}/usr/lib/i386-linux-gnu"
    ln -sfn libbz2.so.1 "%{install-root}/usr/lib/i386-linux-gnu/libbz2.so.1.0"

    # Vulkan manifest discovery link. The i686 vulkan-icd-loader searches
    # %{libdir}/GL/vulkan/icd.d via EXTRASYSCONFDIR; on x86_64 the mesa
    # extension glue provides GL/vulkan, but nothing creates it for the
    # i386 tree, so 32-bit ICDs would go undiscovered without this.
    mkdir -p "%{install-root}/usr/lib/i386-linux-gnu/GL"
    ln -sfn default/vulkan "%{install-root}/usr/lib/i386-linux-gnu/GL/vulkan"

public:
  bst:
    split-rules:
      runtime:
        (>):
        - /usr/lib/i386-linux-gnu/libbz2.so.1.0
        - /usr/lib/i386-linux-gnu/GL/vulkan
