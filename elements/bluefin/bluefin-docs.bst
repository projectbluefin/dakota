kind: manual

# Offline Bluefin documentation, opened by the logo menu's Documentation entry
# (retargeted to the image's Papers in bluefin/common.bst). The documentation
# repository publishes every build as an immutable YY.MM.N release;
# scripts/update_sources.py advances the URL and checksum to the latest one.
sources:
- kind: remote
  url: github_files:projectbluefin/documentation/releases/download/26.11.4/bluefin.pdf
  ref: f45b5e175f5cc00a84965ccf1f4f580aebce14606bfb5edf6f0ec650717a110a
  filename: bluefin.pdf

build-depends:
- core/sandbox-tools.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm644 bluefin.pdf "%{install-root}%{datadir}/doc/bluefin/bluefin.pdf"
