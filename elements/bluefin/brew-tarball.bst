kind: manual

build-depends:
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

runtime-depends:
  - bluefin/brew.bst

sources:
  - kind: remote
    url: github_files:ublue-os/packages/releases/download/homebrew-2026-02-24-01-31-49/homebrew-x86_64.tar.zst
    ref: fbc0702dfb2ece1133e8f817795db8ff4a8afecddd746f2896960578584483cf
variables:
  strip-binaries: ""

config:
  install-commands:
    - |
      mkdir -p "%{install-root}%{datadir}"
      mv homebrew-x86_64.tar.zst "%{install-root}%{datadir}/homebrew.tar.zst"
    - |
      %{install-extra}
