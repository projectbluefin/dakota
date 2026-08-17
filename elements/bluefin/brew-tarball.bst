kind: manual

sources:
- kind: remote
  (?):
  - arch == "x86_64":
      url: github_files:ublue-os/packages/releases/download/homebrew-2026-03-03-01-31-47/homebrew-x86_64.tar.zst
      ref: 46e546da7ac2a4e916f0c89db61e9c0292b90e8b4b6b5662d2c5df5f668fb40c
  - arch == "aarch64":
      url: github_files:ublue-os/packages/releases/download/homebrew-2026-02-17-01-32-11/homebrew-aarch64.tar.zst
      ref: 08813d100ff0f69c57038b1d397e641789701e0ca109200e1377473cd7bad001

build-depends:
- core/sandbox-tools.bst
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
