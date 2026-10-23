kind: manual

description: |
  OpenSnitch daemon backend built from upstream source. This installs the
  `opensnitchd` service and its default config files without pulling the UI.

sources:
# BuildStream sandboxes are network-isolated. Each go_module source stages its
# dependency under vendor/<module> and appends to the generated
# vendor/modules.txt. Keep that output intact and only expose it to the daemon
# checkout via a local vendor symlink.
- kind: git_repo
  url: github:evilsocket/opensnitch.git
  track: master
  ref: a1353848ba1b660320e90cefea782c3fba272c00

- kind: go_module
  url: github:cilium/ebpf.git
  module: github.com/cilium/ebpf
  ref:
    go-version: v0.22.0
    git-ref: e55144e17360b60cc4583229c35c2dbf0935b308
    explicit: True

- kind: go_module
  url: github:fsnotify/fsnotify.git
  module: github.com/fsnotify/fsnotify
  ref:
    go-version: v1.4.7
    git-ref: c2828203cd70a50dcccfb2761f8b1f8ceef9a8e9
    explicit: True

- kind: go_module
  url: github:golang/protobuf.git
  module: github.com/golang/protobuf
  ref:
    go-version: v1.5.0
    git-ref: f746d3b8ecd31eac7c04a954f3905d46b09f8114
    explicit: True

- kind: go_module
  url: github:google/gopacket.git
  module: github.com/google/gopacket
  ref:
    go-version: v1.1.19
    git-ref: a9779d139771f6a06fc983b18e0efd23ca30222f
    explicit: True

- kind: go_module
  url: github:google/nftables.git
  module: github.com/google/nftables
  ref:
    go-version: v0.2.0
    git-ref: 5494b7c55f2ec41dd187ff0b94a2505f6d248a34
    explicit: True

- kind: go_module
  url: github:google/uuid.git
  module: github.com/google/uuid
  ref:
    go-version: v1.3.0
    git-ref: 44b5fee7c49cf3bcdf723f106b36d56ef13ccc88
    explicit: True

- kind: go_module
  url: github:varlink/go.git
  module: github.com/varlink/go
  ref:
    go-version: v0.4.0
    git-ref: 676b6308790ee36f66f74695efc1bcdbc42efb0c
    explicit: True

- kind: go_module
  url: github:vishvananda/netlink.git
  module: github.com/vishvananda/netlink
  ref:
    go-version: v1.3.0
    git-ref: 6f5713947556a0288c5cb71f036f9e91924ebcaa
    explicit: True

- kind: go_module
  url: github:vishvananda/netns.git
  module: github.com/vishvananda/netns
  ref:
    go-version: v0.0.4
    git-ref: 7a452d2d15292b2bfb2a2d88e6bdeac156a761b9
    explicit: True

- kind: go_module
  url: github:golang/net.git
  module: golang.org/x/net
  ref:
    go-version: v0.48.0
    git-ref: 35e1306bddd863f360fb94480c5fed84229953f0
    explicit: True

- kind: go_module
  url: github:golang/sys.git
  module: golang.org/x/sys
  ref:
    go-version: v0.43.0
    git-ref: f33a730cd0c449cfd6f7106780c73052e96cc33d
    explicit: True

- kind: go_module
  url: github:grpc/grpc-go.git
  module: google.golang.org/grpc
  ref:
    go-version: v1.32.0
    git-ref: 5e8f83304c0563d1ba74db05fee83d9c18ab9a58
    explicit: True

- kind: go_module
  url: github:protocolbuffers/protobuf-go.git
  module: google.golang.org/protobuf
  ref:
    go-version: v1.26.0
    git-ref: f2d1f6cbe10b90d22296ea09a7217081c2798009
    explicit: True

- kind: go_module
  url: github:google/go-cmp.git
  module: github.com/google/go-cmp
  ref:
    go-version: v0.7.0
    git-ref: 9b12f366a942ebc7254abc7f32ca05068b455fb7
    explicit: True

- kind: go_module
  url: github:josharian/native.git
  module: github.com/josharian/native
  ref:
    go-version: v1.1.0
    git-ref: c1e37c09b531b14ae12a501eb6fd529b31cecdaa
    explicit: True

- kind: go_module
  url: github:mdlayher/netlink.git
  module: github.com/mdlayher/netlink
  ref:
    go-version: v1.7.2
    git-ref: 657f7da1d9bd78d246ae610e0b5efc63a6a5f9e4
    explicit: True

- kind: go_module
  url: github:mdlayher/socket.git
  module: github.com/mdlayher/socket
  ref:
    go-version: v0.5.1
    git-ref: 9c51a391be6c6bc5b7ce52f328497931c5e97733
    explicit: True

- kind: go_module
  url: github:golang/sync.git
  module: golang.org/x/sync
  ref:
    go-version: v0.20.0
    git-ref: ec11c4a93de22cde2abe2bf74d70791033c2464c
    explicit: True

- kind: go_module
  url: github:golang/text.git
  module: golang.org/x/text
  ref:
    go-version: v0.32.0
    git-ref: 0dd57a6ef90c283b902525213f15d6b2a59cc84b
    explicit: True

- kind: go_module
  url: github:googleapis/go-genproto.git
  module: google.golang.org/genproto
  ref:
    go-version: v0.0.0-20190819201941-24fa4b261c55
    git-ref: 24fa4b261c55da65468f2abfdae2b024eef27dfb
    explicit: True

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:components/go.bst
- freedesktop-sdk.bst:components/gcc.bst
- freedesktop-sdk.bst:components/pkg-config.bst
- freedesktop-sdk.bst:components/protobuf.bst
- freedesktop-sdk.bst:components/sed.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/libmnl.bst
- bluefin/libnetfilter-queue.bst

variables:
  strip-binaries: ""

environment:
  GOROOT: "%{libdir}/go"
  GOARCH: "%{go-arch}"

config:
  build-commands:
  - |
    ln -sfn ../vendor daemon/vendor
    cd daemon
    export PATH="$(go env GOPATH)/bin:$PATH"
    mkdir -p /tmp/protoc-bin
    GOBIN=/tmp/protoc-bin go install -mod=vendor google.golang.org/protobuf/cmd/protoc-gen-go
    GOBIN=/tmp/protoc-bin go install -mod=vendor google.golang.org/grpc/cmd/protoc-gen-go-grpc
    export PATH="/tmp/protoc-bin:$PATH"

    protoc -I../proto --go_out=../daemon/ui/protocol/ --go-grpc_out=../daemon/ui/protocol/ \
      --go_opt=paths=source_relative --go-grpc_opt=paths=source_relative ../proto/ui.proto

    go build -mod=vendor -o opensnitchd .

  install-commands:
  - |
    install -Dm755 daemon/opensnitchd "%{install-root}%{bindir}/opensnitchd"
  - |
    sed -e 's|/usr/local/bin/opensnitchd|/usr/bin/opensnitchd|g' \
        daemon/data/init/opensnitchd.service > opensnitchd.service.patched
    install -Dm644 opensnitchd.service.patched \
      "%{install-root}%{indep-libdir}/systemd/system/opensnitchd.service"
  - |
    install -d "%{install-root}%{sysconfdir}/opensnitchd/rules"
    install -d "%{install-root}%{sysconfdir}/opensnitchd/tasks"
    install -Dm644 daemon/data/default-config.json "%{install-root}%{sysconfdir}/opensnitchd/default-config.json"
    sed -i 's|"Address":"unix:///tmp/osui.sock"|"Address":"127.0.0.1:50051"|g' \
      "%{install-root}%{sysconfdir}/opensnitchd/default-config.json"
    install -Dm644 daemon/data/system-fw.json "%{install-root}%{sysconfdir}/opensnitchd/system-fw.json"
    install -Dm644 daemon/data/network_aliases.json "%{install-root}%{sysconfdir}/opensnitchd/network_aliases.json"
    install -Dm600 daemon/data/tasks/tasks.json "%{install-root}%{sysconfdir}/opensnitchd/tasks/tasks.json"
    install -Dm600 daemon/data/rules/* "%{install-root}%{sysconfdir}/opensnitchd/rules/"
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-opensnitchd.preset"
    cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-opensnitchd.preset" <<'PRESET'
    disable opensnitchd.service
    PRESET
  - "%{install-extra}"
