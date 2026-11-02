kind: manual

# Offline Bluefin documentation, opened by the logo menu's Documentation entry
# (retargeted to the image's Papers in bluefin/common.bst). The documentation
# repository publishes every build as an immutable YY.MM.N release;
# scripts/update_sources.py advances the URL and checksum to the latest one.
sources:
- kind: remote
  url: github_files:projectbluefin/documentation/releases/download/26.11.1/bluefin.pdf
  ref: fc064d114cc6033c8c356c78f4a5869d460e86cea542624759cd51bbbdfef841
  filename: bluefin.pdf

build-depends:
- core/sandbox-tools.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm644 bluefin.pdf "%{install-root}%{datadir}/doc/bluefin/bluefin.pdf"
