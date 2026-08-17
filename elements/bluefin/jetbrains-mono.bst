kind: manual

build-depends:
  - core/sandbox-tools.bst
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

depends:
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

sources:
  - kind: git_repo
    url: github:JetBrains/JetBrainsMono
    track: v*
    ref: v2.304-0-gcd5227bd1f61dff3bbd6c814ceaf7ffd95e947d9

variables:
  license-files-extra: "OFL.txt"
  fontdir: "%{install-root}%{datadir}/fonts"
  strip-binaries: ""

config:
  install-commands:
    - |
      mkdir -p "%{fontdir}/jetbrains-mono"

      install -p -m0644 fonts/otf/*.otf "%{fontdir}/jetbrains-mono"
    - |
      %{install-extra}
