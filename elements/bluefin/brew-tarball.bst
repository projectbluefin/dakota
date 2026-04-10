kind: manual

sources:
- kind: remote
  (?):
  - arch == "x86_64":
      url: github_files:ublue-os/packages/releases/download/homebrew-2026-03-10-01-31-26/homebrew-x86_64.tar.zst
      ref: 644d701fdde130c48ca7b47b2b1af28320819c4176f20c3c208719b3e4dd5c29
  - arch == "aarch64":
      url: github_files:ublue-os/packages/releases/download/homebrew-2026-02-17-01-32-11/homebrew-aarch64.tar.zst
      ref: 08813d100ff0f69c57038b1d397e641789701e0ca109200e1377473cd7bad001

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

runtime-depends:
- bluefin/brew.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    mkdir -p "%{install-root}%{datadir}"
    mv homebrew-%{arch}.tar.zst "%{install-root}%{datadir}/homebrew.tar.zst"
  - |
    %{install-extra}
