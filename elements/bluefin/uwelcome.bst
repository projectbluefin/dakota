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
      url: github_files:projectbluefin/uwelcome/releases/download/v0.3.4/uwelcome_0.3.4_linux_amd64
      ref: f9eba23e8b273ba4add3e4ddfe63a17241caacb82548b78cde187bd5c8021ab6
  - arch == "aarch64":
      url: github_files:projectbluefin/uwelcome/releases/download/v0.3.4/uwelcome_0.3.4_linux_arm64
      ref: 93697c18d9dd99fa77401765576495d0c51b7dbf3a892c45b18bb3487f864362

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm755 uwelcome "%{install-root}%{bindir}/uwelcome"
