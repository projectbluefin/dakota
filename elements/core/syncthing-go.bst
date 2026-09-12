# Private build-only compiler: Syncthing 2.1.5 needs Go >= 1.26.2, while
# Dakota's current fdsdk provides Go 1.25. Do not replace the image toolchain.
# Remove when the integration junction supplies a sufficiently new Go.
kind: manual

sources:
- kind: tar
  url: https://go.dev/dl/go1.26.6.src.tar.gz
  ref: a0721c54c688901448d77ad9b3ec7ea7c474730755ff891382e92ecb93ff2cb1

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:components/go.bst
- freedesktop-sdk.bst:components/gcc.bst
- freedesktop-sdk.bst:components/findutils.bst
- freedesktop-sdk.bst:components/grep.bst
- freedesktop-sdk.bst:components/sed.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

environment:
  GOROOT_BOOTSTRAP: "%{libdir}/go"
  GOARCH: "%{go-arch}"
  GOHOSTARCH: "%{go-arch}"
  GOTOOLCHAIN: "local"
  GOPROXY: "off"
  GOFLAGS: "-trimpath -buildvcs=false"
  CGO_ENABLED: "1"

config:
  build-commands:
  - cd src && bash make.bash

  install-commands:
  - |
    install -d "%{install-root}%{libdir}/syncthing-go"
    cp -a bin pkg src lib VERSION go.env "%{install-root}%{libdir}/syncthing-go/"
  - install -Dm644 LICENSE "%{install-root}%{datadir}/licenses/syncthing-go/LICENSE"
  - "%{install-extra}"
