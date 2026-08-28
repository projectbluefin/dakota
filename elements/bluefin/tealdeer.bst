kind: manual

sources:
  - kind: remote
    filename: tealdeer
    (?):
    - arch == "x86_64":
        url: github_files:tealdeer-rs/tealdeer/releases/download/v1.8.1/tealdeer-linux-x86_64-musl
        ref: 6f2fad4435e0110484d3f25cdc4bf20129dae03238f32d06ebdd00bdc50ae2ed
    - arch == "aarch64":
        url: github_files:tealdeer-rs/tealdeer/releases/download/v1.8.1/tealdeer-linux-aarch64-musl
        ref: 09d4506b3ba2efe7376e3a5ce1238aa5e6c33ae6f2532c190156540f6c4e7d69
  - kind: remote
    url: github_files:tealdeer-rs/tealdeer/releases/download/v1.8.1/completions_bash
    ref: 3a14c45f758ce95ba088c79cd2c0a5b6890a8255d51af22028d4f3ebe977a656
    filename: completions_bash
  - kind: remote
    url: github_files:tealdeer-rs/tealdeer/releases/download/v1.8.1/completions_zsh
    ref: 8b2d55757af91c3fa594c0f2fe57eebf0db48e13451430319ea6d093b65e6889
    filename: completions_zsh
  - kind: remote
    url: github_files:tealdeer-rs/tealdeer/releases/download/v1.8.1/completions_fish
    ref: fe7cd5f0ca44cb53a40606fedf920a85fdc2ca005ef26e77263399ab524ed4f6
    filename: completions_fish

build-depends:
  - core/sandbox-tools.bst
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
