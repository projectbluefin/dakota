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
      url: github_files:projectbluefin/uwelcome/releases/download/v0.5.1/uwelcome_0.5.1_linux_amd64
      ref: cdd7acc55fb7955b96497c80efdc89e1dfc3ee24fb9a1a8d1b7b53ef949ecce3
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
