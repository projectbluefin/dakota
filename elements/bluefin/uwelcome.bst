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
      url: github_files:projectbluefin/uwelcome/releases/download/v0.3.5/uwelcome_0.3.5_linux_amd64
      ref: f13733173f3612ffb5de3cf4d49b608198b4db65a24e6421c4c83df4d72d7aab
  - arch == "aarch64":
      url: github_files:projectbluefin/uwelcome/releases/download/v0.3.5/uwelcome_0.3.5_linux_arm64
      ref: 5b38d182fd7152bac541d0bc8abdf1a04cab848ab0c62d6bba5ef79477342afb

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm755 uwelcome "%{install-root}%{bindir}/uwelcome"
