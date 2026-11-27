# Incus 7.2 LTS — system container and VM manager, built from its vendored release tarball.
kind: manual

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:components/go.bst
- freedesktop-sdk.bst:components/pkg-config.bst
- freedesktop-sdk.bst:components/gcc.bst
- bluefin/incus-deps/cowsql.bst
- bluefin/incus-deps/lxc.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

runtime-depends:
- bluefin/incus-deps/cowsql.bst
- bluefin/incus-deps/lxc.bst
- bluefin/incus-deps/lxcfs.bst
- bluefin/virtiofsd.bst
- gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/qemu.bst
- gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/swtpm.bst
- freedesktop-sdk.bst:components/ovmf-maybe.bst
- freedesktop-sdk.bst:components/ca-certificates.bst
- core/dnsmasq.bst
- freedesktop-sdk.bst:components/nftables.bst
- freedesktop-sdk.bst:components/apparmor.bst
- freedesktop-sdk.bst:components/iproute2.bst
- freedesktop-sdk.bst:components/btrfs-progs.bst
- freedesktop-sdk.bst:components/lvm2.bst
- freedesktop-sdk.bst:components/squashfs-tools.bst
- freedesktop-sdk.bst:components/rsync.bst
- freedesktop-sdk.bst:components/shadow.bst
- freedesktop-sdk.bst:components/tar.bst
- freedesktop-sdk.bst:components/util-linux.bst
- freedesktop-sdk.bst:components/xz.bst

public:
  bst:
    integration-commands:
    - |
      for file in /etc/subuid /etc/subgid; do
        grep -qxF 'root:1000000:1000000000' "$file" || printf '%s\n' 'root:1000000:1000000000' >> "$file"
      done

variables:
  strip-binaries: ""

environment:
  GOROOT: "%{libdir}/go"
  GOARCH: "%{go-arch}"
  GOFLAGS: "-mod=vendor -trimpath -buildvcs=false"
  GO111MODULE: "on"
  CGO_LDFLAGS_ALLOW: "(-Wl,-wrap,pthread_create)|(-Wl,-z,now)"

config:
  build-commands:
  - |
    export GOBIN="${PWD}/_bin"
    export GOPATH="${PWD}/_gopath"
    export GOCACHE="${PWD}/_gocache"
    mkdir -p "$GOBIN"
    CGO_ENABLED=1 go install -v -tags libsqlite3 -ldflags "-s -w" ./...
    CGO_ENABLED=0 go install -v -tags agent,netgo -ldflags "-s -w" ./cmd/incus-agent
    CGO_ENABLED=0 go install -v -tags netgo -ldflags "-s -w" ./cmd/incus-migrate

  install-commands:
  - |
    install -Dm755 _bin/incus _bin/incus-migrate -t "%{install-root}%{bindir}"
    install -d "%{install-root}%{libexecdir}/incus"
    install -m755 _bin/incusd _bin/incus-user _bin/incus-agent "%{install-root}%{libexecdir}/incus/"
    install -m700 _bin/fuidshift "%{install-root}%{libexecdir}/incus/fuidshift"
  - |
    install -d "%{install-root}%{datadir}/bash-completion/completions"
    _bin/incus completion bash > "%{install-root}%{datadir}/bash-completion/completions/incus"
    install -d "%{install-root}%{datadir}/zsh/site-functions"
    _bin/incus completion zsh > "%{install-root}%{datadir}/zsh/site-functions/_incus"
  - |
    install -Dm644 -t "%{install-root}%{indep-libdir}/systemd/system" \
      incus.socket incus.service incus-startup.service incus-user.socket incus-user.service
    install -Dm644 -t "%{install-root}%{indep-libdir}/systemd/system-preset" 80-incus.preset
    install -Dm644 incus-sysusers.conf "%{install-root}%{indep-libdir}/sysusers.d/incus.conf"
    install -Dm644 incus-tmpfiles.conf "%{install-root}%{indep-libdir}/tmpfiles.d/incus.conf"
    install -Dm644 incus-modules.conf "%{install-root}%{indep-libdir}/modules-load.d/incus.conf"
    install -Dm644 default-incus "%{install-root}%{sysconfdir}/default/incus"
  - install -Dm644 COPYING "%{install-root}%{datadir}/licenses/incus/COPYING"
  - "%{install-extra}"

sources:
- kind: tar
  url: github_files:lxc/incus/releases/download/v7.2.0/incus-7.2.0.tar.gz
  ref: f24644f968d0fbfbb6c6dbe57f4c6e30ae89b1b186e0f855b21ae640f6bcecda
- kind: local
  path: files/incus/incus.socket
- kind: local
  path: files/incus/incus.service
- kind: local
  path: files/incus/incus-startup.service
- kind: local
  path: files/incus/incus-user.socket
- kind: local
  path: files/incus/incus-user.service
- kind: local
  path: files/incus/80-incus.preset
- kind: local
  path: files/incus/incus-sysusers.conf
- kind: local
  path: files/incus/incus-tmpfiles.conf
- kind: local
  path: files/incus/incus-modules.conf
- kind: local
  path: files/incus/default-incus
