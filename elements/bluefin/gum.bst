kind: manual

sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: github_files:charmbracelet/gum/releases/download/v2.0.2/gum_2.0.2_Linux_x86_64.tar.gz
      ref: d842e06d93dbed90af48cb8dd10698db6f22e331fc40346bb37bbc753109edc2
  - arch == "aarch64":
      url: github_files:charmbracelet/gum/releases/download/v2.0.2/gum_2.0.2_Linux_arm64.tar.gz
      ref: 8ebf8b54ec1e8c81f2bb58b59ff9b70998186a4d11375f0cf357b80e0ccfa1d5

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
