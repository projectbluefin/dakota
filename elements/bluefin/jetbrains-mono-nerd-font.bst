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
  url: github_files:ryanoasis/nerd-fonts/releases/download/v3.5.0/JetBrainsMono.tar.xz
  ref: 0227b220360a6f819b9ead92343e8112b34733054782561af50cfba1e8afab63
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
