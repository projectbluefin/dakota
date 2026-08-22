kind: manual

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/libarchive.bst
- freedesktop-sdk.bst:components/bzip2.bst
- freedesktop-sdk.bst:components/xz.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

sources:
  # kind: tar fails on this specific archive. No idea why.
  # FIXME: build the nerd fonts ourselves
- kind: remote
  url: github_files:ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz
  ref: 04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf
variables:
  license-files-extra: "OFL.txt"
  fontdir: "%{install-root}%{datadir}/fonts"
  strip-binaries: ""

config:
  install-commands:
  - |
    bsdtar -o -xvf JetBrainsMono.tar.xz
    rm JetBrainsMono.tar.xz
  - |
    mkdir -p "%{fontdir}/jetbrains-mono-nerd-font"
    install -p -m0644 *.ttf "%{fontdir}/jetbrains-mono-nerd-font"
  - |
    %{install-extra}
