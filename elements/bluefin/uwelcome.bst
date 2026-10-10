# uwelcome renders the login welcome screen and MOTD. common ships the hooks
# that invoke it (/etc/profile.d/uwelcome.sh, fish greeting, /etc/uwelcome)
# but builds the binary in its Containerfile, which Dakota does not consume,
# so we ship the release binary ourselves like umotd.bst.
kind: manual

sources:
- kind: remote
  filename: uwelcome
  (?):
  - arch == "x86_64":
      url: github_files:projectbluefin/uwelcome/releases/download/v0.4.1/uwelcome_0.4.1_linux_amd64
      ref: 13ffba0b4e46b180af913c4842f910b0da5f7a925e28705c1173b2021b7d3018
  - arch == "aarch64":
      url: github_files:projectbluefin/uwelcome/releases/download/v0.4.1/uwelcome_0.4.1_linux_arm64
      ref: 7f42299444ab5a26f9d62ef6385ff5d7029c3f367a42272bede05bd351615472

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm755 uwelcome "%{install-root}%{bindir}/uwelcome"
