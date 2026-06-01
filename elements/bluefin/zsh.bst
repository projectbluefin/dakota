kind: manual

sources:
- kind: tar
  base-dir: ""
  (?):
  - arch == "x86_64":
      url: github_files:romkatv/zsh-bin/releases/download/v6.1.1/zsh-5.8-linux-x86_64.tar.gz
      ref: 6df668fb6e9a12874e0d80518d582f2e99e512d4a4532fa73d938360aaddc838
  - arch == "aarch64":
      url: github_files:romkatv/zsh-bin/releases/download/v6.1.1/zsh-5.8-linux-aarch64.tar.gz
      ref: 5caca77bcdaa218ec12e79f2e65c53c39058e0ed4f4f299991d18a800ca7c06d

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    cp -r bin share "%{install-root}%{prefix}/"
  - |
    %{install-extra}
