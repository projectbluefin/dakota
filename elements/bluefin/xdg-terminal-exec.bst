kind: manual

sources:
- kind: git_repo
  url: github:Vladimir-csp/xdg-terminal-exec.git
  track: 'v[0-9]*.[0-9]*.[0-9]*'
  ref: v0.14.3-0-g065925df9f419008159258ae169018bfd23df71b

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 xdg-terminal-exec "%{install-root}%{bindir}/xdg-terminal-exec"
  - |
    install -Dm644 xdg-terminals.list "%{install-root}%{datadir}/xdg-terminal-exec/xdg-terminals.list"
  - |
    %{install-extra}
