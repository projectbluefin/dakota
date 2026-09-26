kind: manual
description: |
  gocryptfs userspace encrypted filesystem used by projectbluefin/contribute.

sources:
- kind: git_repo
  url: github:rfjakob/gocryptfs.git
  track: v2.6.1
  ref: v2.6.1-0-g25e85a4454e93643ad92397d01ed532a360d7ee2
- kind: go_module
  url: github:aperturerobotics/jacobsa-crypto.git
  module: github.com/aperturerobotics/jacobsa-crypto
  ref:
    go-version: v1.1.0
    git-ref: af52270f8fe6132d8077b33e515ec4f8c542980d
    explicit: true
- kind: go_module
  url: github:hanwen/go-fuse.git
  module: github.com/hanwen/go-fuse/v2
  ref:
    go-version: v2.8.0
    git-ref: ee34567408d6ab557a0169089879ec111bd74408
    explicit: true
- kind: go_module
  url: github:moby/sys.git
  module: github.com/moby/sys/mountinfo
  ref:
    go-version: v0.7.2
    git-ref: cafbe42351600ca9b363e220722f66d96f6e71f4
    explicit: true
- kind: go_module
  url: github:pkg/xattr.git
  module: github.com/pkg/xattr
  ref:
    go-version: v0.4.9
    git-ref: 87ba458273dc4e1cfef4d6d43faffdcf7e9077be
    explicit: true
- kind: go_module
  url: github:rfjakob/eme.git
  module: github.com/rfjakob/eme
  ref:
    go-version: v1.1.2
    git-ref: f867e203db5dfe7d05a58a59e9042e864b1eb19e
    explicit: true
- kind: go_module
  url: github:sabhiram/go-gitignore.git
  module: github.com/sabhiram/go-gitignore
  ref:
    go-version: v0.0.0-20210923224102-525f6e181f06
    git-ref: 525f6e181f062064d83887ed2530e3b1ba0bc95a
    explicit: true
- kind: go_module
  url: github:spf13/pflag.git
  module: github.com/spf13/pflag
  ref:
    go-version: v1.0.5
    git-ref: 2e9d26c8c37aae03e3f9d4e90b7116f5accb7cab
    explicit: true
- kind: go_module
  url: github:golang/crypto.git
  module: golang.org/x/crypto
  ref:
    go-version: v0.33.0
    git-ref: 9290511cd23ab9813a307b7f2615325e3ca98902
    explicit: true
- kind: go_module
  url: github:golang/sys.git
  module: golang.org/x/sys
  ref:
    go-version: v0.30.0
    git-ref: 863b3c4ac4975ff758815fa8d01acb6771f37177
    explicit: true
- kind: go_module
  url: github:golang/term.git
  module: golang.org/x/term
  ref:
    go-version: v0.29.0
    git-ref: 743b2709ab25357d30ce1eac4a840eb0b7deb1bf
    explicit: true

build-depends:
- freedesktop-sdk.bst:components/go.bst
- freedesktop-sdk.bst:components/fuse3.bst

depends:
- freedesktop-sdk.bst:components/fuse3.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

environment:
  GOTOOLCHAIN: local
  GOPROXY: off
  GOFLAGS: -trimpath -buildvcs=false
  SOURCE_DATE_EPOCH: "1754852649"

variables:
  strip-binaries: ''

config:
  build-commands:
  - CGO_ENABLED=0 go build -mod=vendor -tags without_openssl -ldflags="-X main.GitVersion=v2.6.1 -X main.GitVersionFuse=v2.8.0 -X main.BuildDate=2025-08-10" -o gocryptfs .
  - CGO_ENABLED=0 go build -mod=vendor -ldflags="-X main.GitVersion=v2.6.1 -X main.BuildDate=2025-08-10" -o gocryptfs-xray/gocryptfs-xray ./gocryptfs-xray
  install-commands:
  - install -Dm755 gocryptfs "%{install-root}%{bindir}/gocryptfs"
  - install -Dm755 gocryptfs-xray/gocryptfs-xray "%{install-root}%{bindir}/gocryptfs-xray"
