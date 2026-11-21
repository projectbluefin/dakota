kind: manual

# Offline Bluefin documentation, opened by the logo menu's Documentation entry
# (retargeted to the image's Papers in bluefin/common.bst). The documentation
# repository publishes every build as an immutable YY.MM.N release;
# scripts/update_sources.py advances the URL and checksum to the latest one.
sources:
- kind: remote
  url: github_files:projectbluefin/documentation/releases/download/26.11.3/bluefin.pdf
  ref: 44324d8ddeb9037b36c31ba903e3dd412064eb47685d2369dff6a2c4089935b3
  filename: bluefin.pdf

build-depends:
- core/sandbox-tools.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm644 bluefin.pdf "%{install-root}%{datadir}/doc/bluefin/bluefin.pdf"
