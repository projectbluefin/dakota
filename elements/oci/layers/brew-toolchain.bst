# Minimal host toolchain retained for Homebrew source builds. The filtered
# closure is reclassified as runtime content so the final image can exclude the
# rest of the OS development files in a single full-root composition.
kind: filter

build-depends:
- oci/layers/brew-toolchain-closure.bst

config:
  include:
  - host-toolchain
  exclude:
  - runtime-authoritative
  include-orphans: false

public:
  bst:
    split-rules:
      runtime:
      - '/**'
      devel: []
