kind: manual

sources:
  # - kind: git_repo
  #   url: github:ublue-os/artwork.git
  #   track: main
- kind: tar
  url: github_files:ublue-os/artwork/releases/download/bluefin-v2026-08-21/bluefin-wallpapers-gnome.tar.zstd
  ref: b3c5332f28c06265aa39284c0e1fad5ec970860d06737ebae24072a17cb52bf4
  base-dir: ""

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
    cp -r *.jxl *.xml "%{install-root}%{datadir}/backgrounds/bluefin"
    cp -r gnome-background-properties "%{install-root}%{datadir}/gnome-background-properties"
  - "%{install-extra}"
