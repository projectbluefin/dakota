# Small compatibility symlinks for Debian/Ubuntu-style SONAMEs expected by
# Valve's 32-bit Steam client packages.
kind: manual

build-depends:
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

public:
  bst:
    split-rules:
      runtime:
        (>):
        - /usr/lib/i386-linux-gnu/libbz2.so.1.0
