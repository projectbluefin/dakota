kind: manual

sources:
- kind: remote
  filename: tealdeer
  (?):
  - arch == "x86_64":
      url: github_files:tealdeer-rs/tealdeer/releases/download/v1.9.1/tealdeer-linux-x86_64-musl
      ref: 5a9c3f0691b9cf375ee5c99de802885f3d50498cf686a539e2ddda028eb6b4f6
  - arch == "aarch64":
      url: github_files:tealdeer-rs/tealdeer/releases/download/v1.8.1/tealdeer-linux-aarch64-musl
      ref: 09d4506b3ba2efe7376e3a5ce1238aa5e6c33ae6f2532c190156540f6c4e7d69
- kind: remote
  url: github_files:tealdeer-rs/tealdeer/releases/download/v1.9.1/completions_bash
  ref: 3a14c45f758ce95ba088c79cd2c0a5b6890a8255d51af22028d4f3ebe977a656
  filename: completions_bash
- kind: remote
  url: github_files:tealdeer-rs/tealdeer/releases/download/v1.9.1/completions_zsh
  ref: 3ece1ec1b2ac801f38e403c2587c65935131549546ec229292b49de8cd35cb7c
  filename: completions_zsh
- kind: remote
  url: github_files:tealdeer-rs/tealdeer/releases/download/v1.9.1/completions_fish
  ref: 0a60756306afe412ee5fb604482e9edb14be7d38244ca067715404e2133fdc4c
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
