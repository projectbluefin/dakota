kind: manual

sources:
- kind: remote
  filename: tmux.gz
  (?):
  - arch == "x86_64":
      url: github_files:mjakob-gh/build-static-tmux/releases/download/v3.6b/tmux.linux-amd64.stripped.gz
      ref: a23e56e9913d610c31f2893a1c9c669a73cb8bb2b8ded1180f6572bb55e52ca5
  - arch == "aarch64":
      url: github_files:mjakob-gh/build-static-tmux/releases/download/v3.6b/tmux.linux-arm64.stripped.gz
      ref: c47968fab66e5d0eda6eaf547e1318412d35e180b95b1400bffa659960de8638

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    gunzip -c tmux.gz > tmux
    install -Dm755 -t "%{install-root}%{bindir}" tmux
  - |
    %{install-extra}
