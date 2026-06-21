kind: manual

sources:
- kind: remote
  filename: umotd
  (?):
  - arch == "x86_64":
      url: github_files:projectbluefin/motd/releases/download/v0.2.1/umotd_0.2.1_linux_amd64
      ref: 7f75e9c2f440448f7f23e8ae3b108d274a96bbc50aaba52776f35c00260e1e49
  - arch == "aarch64":
      url: github_files:projectbluefin/motd/releases/download/v0.2.1/umotd_0.2.1_linux_arm64
      ref: d6da4d57f81e6c15d7738b9bd986ffc6915fa79a40426bcca079c2079ec60b06

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm755 umotd "%{install-root}%{bindir}/umotd"
