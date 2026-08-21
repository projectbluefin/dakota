kind: manual

sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: github_files:charmbracelet/gum/releases/download/v2.0.0/gum_2.0.0_Linux_x86_64.tar.gz
      ref: c99b0005bb5b514770eea404b24c7987e08eba35bb0b2d7bc6545bb676c36861
  - arch == "aarch64":
      url: github_files:charmbracelet/gum/releases/download/v2.0.0/gum_2.0.0_Linux_arm64.tar.gz
      ref: ed51e91457a48f5681f67dd925bd40eb1794d41d1f48cf1d7e19e2517b7fac76

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
