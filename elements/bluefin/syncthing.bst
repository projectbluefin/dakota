# The release source archive includes the complete Go vendor tree and web UI.
kind: manual

sources:
- kind: tar
  url: github:syncthing/syncthing/releases/download/v2.1.7/syncthing-source-v2.1.7.tar.gz
  ref: 5b84abd0e8b187f618fb2c38c37fa37ce0b377a275d3e0b981bad94176a24afa

build-depends:
- core/sandbox-tools.bst
- core/syncthing-go.bst
- freedesktop-sdk.bst:components/gcc.bst

runtime-depends:
- gnome-build-meta.bst:core-deps/systemd.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

environment:
  GOROOT: "%{libdir}/syncthing-go"
  GOARCH: "%{go-arch}"
  GOFLAGS: "-mod=vendor -buildvcs=false -trimpath"
  GOPROXY: "off"
  GOTOOLCHAIN: "local"
  CGO_ENABLED: "1"
  BUILD_USER: "dakota"
  BUILD_HOST: "buildstream"
  SOURCE_DATE_EPOCH: "1"

config:
  build-commands:
  - export PATH="$GOROOT/bin:$PATH"; go run build.go --version v2.1.5 --no-upgrade build

  install-commands:
  - install -Dm755 syncthing "%{install-root}%{bindir}/syncthing"
  - install -Dm644 etc/linux-systemd/user/syncthing.service "%{install-root}%{indep-libdir}/systemd/user/syncthing.service"
  # The Quick Settings control starts it on demand. Do not start sharing or
  # generate an identity during image construction or for every login.
  - |
    install -d "%{install-root}%{indep-libdir}/systemd/user-preset"
    printf 'disable syncthing.service\n' > "%{install-root}%{indep-libdir}/systemd/user-preset/80-syncthing.preset"
  - install -Dm644 LICENSE "%{install-root}%{datadir}/licenses/syncthing/LICENSE"
  - "%{install-extra}"
