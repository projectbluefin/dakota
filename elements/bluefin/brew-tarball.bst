kind: manual

sources:
# The docker source pins the per-architecture manifest digest, not the
# multi-arch index digest, so each arch carries its own ref (tracked with
# `just bst -o arch <arch> source track bluefin/brew-tarball.bst`).
- kind: docker
  url: ghcr:ublue-os/brew
  track: latest
  (?):
  - arch == "x86_64":
      ref: e0edae28a2ce41e2faa05b9a4902488a9a22d5c4a70c94427ccac8904ec5107a
  - arch == "aarch64":
      ref: aff477fa0ccbbb467946ed12e1ec6cd7726281e555daa152ef64af8f3106a5e6

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
    install -Dm644 system_files/usr/share/homebrew.tar.zst \
      "%{install-root}%{datadir}/homebrew.tar.zst"
  - |
    %{install-extra}
