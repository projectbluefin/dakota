kind: manual

sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: github_files:charmbracelet/gum/releases/download/v2.0.1/gum_2.0.1_Linux_x86_64.tar.gz
      ref: 4dfe4547f960813864c803b3617aa64427fa32ca566707fde949e08975297c48
  - arch == "aarch64":
      url: github_files:charmbracelet/gum/releases/download/v2.0.1/gum_2.0.1_Linux_arm64.tar.gz
      ref: 6998202a8fea27bb2007f69e44ec5dcb4cff5268c62d995de857eee0e2cd52cb

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 -t "%{install-root}%{bindir}" gum
  - |
    install -Dm644 -t "%{install-root}%{datadir}/bash-completion/completions" completions/gum.bash
    install -Dm644 -t "%{install-root}%{datadir}/zsh/site-functions" completions/gum.zsh
    install -Dm644 -t "%{install-root}%{datadir}/fish/vendor_completions.d" completions/gum.fish
  - |
    install -Dm644 -t "%{install-root}%{datadir}/man/man1" manpages/gum.1.gz
  - |
    %{install-extra}
