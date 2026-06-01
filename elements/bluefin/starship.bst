kind: manual

sources:
- kind: tar
  base-dir: ""
  (?):
  - arch == "x86_64":
      url: github_files:starship/starship/releases/download/v1.25.1/starship-x86_64-unknown-linux-musl.tar.gz
      ref: c6ddd3ecb9c0071a2ad38d98cee748160066b7c4f197421268058f4a5d6f8504
  - arch == "aarch64":
      url: github_files:starship/starship/releases/download/v1.25.1/starship-aarch64-unknown-linux-musl.tar.gz
      ref: 01517aab398959ea9ea73bdb4f032ea4dbb51dff5c8e5eb05b4a1b9b7ab872b8

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 -t "%{install-root}%{bindir}" starship
  - |
    %{install-extra}
