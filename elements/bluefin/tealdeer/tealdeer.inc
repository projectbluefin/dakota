build-depends:
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
    - |
      install -Dm755 tealdeer "%{install-root}%{bindir}/tldr"
      install -Dm644 completions_bash "%{install-root}%{datadir}/bash-completion/completions/tldr"
      install -Dm644 completions_zsh "%{install-root}%{datadir}/zsh/site-functions/_tldr"
      install -Dm644 completions_fish "%{install-root}%{datadir}/fish/vendor_completions.d/tldr.fish"
      %{install-extra}
