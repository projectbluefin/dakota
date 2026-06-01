kind: manual

sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: github_files:fastfetch-cli/fastfetch/releases/download/2.63.1/fastfetch-linux-amd64.tar.gz
      ref: 75dcbcf5dbe51a6c3785767085bda00f5253af46a1292a6444746b33215d4199
  - arch == "aarch64":
      url: github_files:fastfetch-cli/fastfetch/releases/download/2.63.1/fastfetch-linux-aarch64.tar.gz
      ref: 2f4fc07751d2cdf3d8cb41ef6598699a1a4da5e7c50a0ea67ea601077a3d6ac1

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    cp -r usr/./ "%{install-root}%{prefix}/"
  - |
    %{install-extra}
