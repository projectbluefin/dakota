kind: compose

build-depends:
  - freedesktop-sdk.bst:components/gcc.bst
  # Homebrew native builds only see /usr/bin and brick the persistent
  # prefix when make is missing (.agents/skills/dakota-workstation/references/host-homebrew.md)
  - freedesktop-sdk.bst:components/make.bst
  - oci/layers/bluefin-runtime.bst

config:
  exclude:
    - debug
    - extra
    - static-blocklist
