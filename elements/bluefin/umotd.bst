kind: manual

sources:
- kind: remote
  filename: umotd
  (?):
  - arch == "x86_64":
      url: github_files:theMimolet/umotd/releases/download/v0.2.1/umotd_0.2.1_linux_amd64
      ref: 2cd5a07344f553e590b432aa5b3a07c5cbd055487468d33514130ae5f05ba02e
  - arch == "aarch64":
      url: github_files:theMimolet/umotd/releases/download/v0.2.1/umotd_0.2.1_linux_arm64
      ref: 1598bb13f30f3c2e17fe4349fd04f567999a0643919d5a4abb186a14cb7d62f0

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm755 umotd "%{install-root}%{bindir}/umotd"
