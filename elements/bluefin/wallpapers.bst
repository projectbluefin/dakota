kind: manual

sources:
# Docker source pins the per-architecture manifest digest from projectbluefin/artwork.
# Multi-arch index: ghcr.io/projectbluefin/bluefin-wallpapers-gnome:v20261020
- kind: docker
  url: ghcr:projectbluefin/bluefin-wallpapers-gnome
  track: latest
  (?):
  - arch == "x86_64":
      ref: 674daa6a8fbb2054d40fa8d94f2f57647d7d8061515445ca1f16a1c895652b1e
  - arch == "aarch64":
      ref: 18637092c7c955a5d3fe58084ef0b7658a9a4903e03f2a944e6478f4825694a9

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:components/sed.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    sed -i 's|~\/\.local\/share|\/usr\/share|' *.xml gnome-background-properties/*.xml
    mkdir -p "%{install-root}%{datadir}/backgrounds/bluefin"
    cp -r *.jxl *.svg *.xml "%{install-root}%{datadir}/backgrounds/bluefin"
    cp -r gnome-background-properties "%{install-root}%{datadir}/gnome-background-properties"
  - "%{install-extra}"
