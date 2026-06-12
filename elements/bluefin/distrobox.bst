# Override: distrobox next branch (Go port).
# Replaces gnome-build-meta.bst:gnomeos-deps/distrobox.bst (shell-based).
# Tracks 89luca89/distrobox:next — the full Go rewrite.
kind: manual

build-depends:
- freedesktop-sdk.bst:components/go.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

runtime-depends:
- freedesktop-sdk.bst:components/podman.bst

variables:
  strip-binaries: ""

environment:
  GOARCH: "%{go-arch}"

config:
  build-commands:
  - mv -vf modules.txt vendor/modules.txt
  - CGO_ENABLED=0 go build -mod=vendor -ldflags="-s -w" -o ./bin/distrobox ./cmd/distrobox

  install-commands:
  - install -Dm755 ./bin/distrobox "%{install-root}%{bindir}/distrobox"
  - |
    for cmd in assemble create enter ephemeral generate-entry list ls rm stop upgrade; do
      ln -sf distrobox "%{install-root}%{bindir}/distrobox-${cmd}"
    done
  - install -Dm644 completions/bash/distrobox "%{install-root}%{datadir}/bash-completion/completions/distrobox"
  - install -Dm644 completions/zsh/_distrobox "%{install-root}%{datadir}/zsh/site-functions/_distrobox"
  - install -d "%{install-root}%{mandir}/man1"
  - install -m644 man/man1/*.1 "%{install-root}%{mandir}/man1/"
  - "%{install-extra}"

sources:
- kind: git_repo
  url: github:89luca89/distrobox.git
  track: next
  ref: 1.8.2.5-150-g5f52050dabb3c0e1a5a2350ceed77ac92e25c88e

- kind: local
  path: files/distrobox/modules.txt

- kind: go_module
  url: github:davecgh/go-spew.git
  module: github.com/davecgh/go-spew
  ref:
    go-version: v1.1.1
    git-ref: v1.1.1-0-g8991bc29aa16c548c550c7ff78260e27b9ab7c73
    explicit: True

- kind: go_module
  url: github:pmezard/go-difflib.git
  module: github.com/pmezard/go-difflib
  ref:
    go-version: v1.0.0
    git-ref: v1.0.0-0-g792786c7400a136282c1664665ae0a8db921c6c2
    explicit: True

- kind: go_module
  url: github:stretchr/testify.git
  module: github.com/stretchr/testify
  ref:
    go-version: v1.11.1
    git-ref: v1.11.1-0-g2a57335dc9cd6833daa820bc94d9b40c26a7917d
    explicit: True

- kind: go_module
  url: github:urfave/cli.git
  module: github.com/urfave/cli/v3
  ref:
    go-version: v3.5.0
    git-ref: v3.5.0-0-g495e1d30c76923fbefbc095c0b01f9398529bb67
    explicit: True

- kind: go_module
  url: github:go-ini/ini.git
  module: gopkg.in/ini.v1
  ref:
    go-version: v1.67.0
    git-ref: v1.67.0-0-gb2f570e5b5b844226bbefe6fb521d891f529a951
    explicit: True

- kind: go_module
  url: github:go-yaml/yaml.git
  module: gopkg.in/yaml.v3
  ref:
    go-version: v3.0.1
    git-ref: v3.0.1-0-gf6f7691b1fdeb513f56608cd2c32c51f8194bf51
    explicit: True
