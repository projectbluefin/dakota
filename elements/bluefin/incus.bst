# Incus — system container & VM manager (LXC/LXD lineage, lxc/incus).
#
# Built from the upstream release tarball, which bundles all Go dependencies
# under vendor/ (so we build with -mod=vendor, like ghostty's release tarball
# — no per-module go_module list to maintain).
#
# incusd is CGO and links cowsql + liblxc via pkg-config; the daemon is built
# with the `libsqlite3` tag (the Makefile probes for <cowsql.h> to set it).
# incus-agent and incus-migrate run *inside* guests, so they are built static
# (CGO_ENABLED=0, netgo) to avoid dragging host libs into instances.
kind: manual

build-depends:
- freedesktop-sdk.bst:components/go.bst
- freedesktop-sdk.bst:components/pkg-config.bst
# CGO needs a C toolchain on PATH. This is a `kind: manual` element, so unlike
# the meson/autotools libs it doesn't get one implicitly. gcc.bst provides
# gcc + the `cc` symlink and runtime-depends binutils (ld) for the CGO link.
- freedesktop-sdk.bst:components/gcc.bst
- bluefin/incus-deps/cowsql.bst
- bluefin/incus-deps/lxc.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

# Runtime closure: the libraries incusd dlopens/links plus the external tools
# it shells out to. All of these already exist in the junctions except the
# incus-deps/* elements we author alongside this one.
runtime-depends:
- bluefin/incus-deps/cowsql.bst
- bluefin/incus-deps/lxc.bst
- bluefin/incus-deps/lxcfs.bst
- gnome-build-meta.bst:core-deps/qemu.bst              # VM backend
- freedesktop-sdk.bst:components/ovmf-maybe.bst        # UEFI firmware for VMs (arch-guarded)
- freedesktop-sdk.bst:components/ca-certificates.bst   # TLS for image servers
- gnome-build-meta.bst:gnomeos-deps/virtiofsd.bst      # VM dir sharing
- gnome-build-meta.bst:gnomeos-deps/swtpm.bst          # VM TPM 2.0
- gnome-build-meta.bst:core-deps/dnsmasq.bst           # managed-bridge DHCP/DNS
- gnome-build-meta.bst:gnomeos-deps/nftables.bst       # NAT / firewall
- freedesktop-sdk.bst:components/iproute2.bst          # bridges, routes
- freedesktop-sdk.bst:components/btrfs-progs.bst       # btrfs storage pools
- freedesktop-sdk.bst:components/lvm2.bst              # lvm storage pools
- freedesktop-sdk.bst:components/squashfs-tools.bst    # image packing
- freedesktop-sdk.bst:components/rsync.bst             # copy/migration
- freedesktop-sdk.bst:components/shadow.bst            # newuidmap/newgidmap (unpriv)

public:
  bst:
    overlap-whitelist:
    - '%{sysconfdir}/subuid'
    - '%{sysconfdir}/subgid'

variables:
  strip-binaries: ""

environment:
  GOARCH: "%{go-arch}"
  GOFLAGS: "-mod=vendor"
  GO111MODULE: "on"
  # cowsql links with -Wl,-wrap,pthread_create; Go blocks unknown linker
  # flags unless explicitly allowed (mirrors the upstream Makefile).
  CGO_LDFLAGS_ALLOW: "(-Wl,-wrap,pthread_create)|(-Wl,-z,now)"

config:
  build-commands:
  - |
    export GOBIN="${PWD}/_bin"
    export GOPATH="${PWD}/_gopath"
    export GOCACHE="${PWD}/_gocache"
    mkdir -p "$GOBIN"

    # Daemon, client, and cgo helpers (incusd, incus, incus-user, fuidshift,
    # incus-benchmark, ...). Linked against cowsql + liblxc via pkg-config.
    CGO_ENABLED=1 go install -v -tags libsqlite3 -ldflags "-s -w" ./...

    # Guest-side binaries: fully static so they run inside any instance.
    CGO_ENABLED=0 go install -v -tags "agent,netgo" -ldflags "-s -w" ./cmd/incus-agent
    CGO_ENABLED=0 go install -v -tags "netgo"        -ldflags "-s -w" ./cmd/incus-migrate

  install-commands:
  - |
    install -Dm755 -t "%{install-root}%{bindir}" \
      _bin/incus _bin/incusd _bin/incus-user _bin/incus-agent \
      _bin/incus-migrate _bin/fuidshift

  # Shell completions (offline; the client generates them itself).
  - |
    install -d "%{install-root}%{datadir}/bash-completion/completions"
    _bin/incus completion bash > "%{install-root}%{datadir}/bash-completion/completions/incus" || true
    install -d "%{install-root}%{datadir}/zsh/site-functions"
    _bin/incus completion zsh  > "%{install-root}%{datadir}/zsh/site-functions/_incus" || true

  # Host systemd units + preset (not shipped by upstream; authored in files/).
  - |
    install -Dm644 -t "%{install-root}%{indep-libdir}/systemd/system" \
      incus.socket incus.service incus-startup.service incus-user.socket incus-user.service
    install -Dm644 -t "%{install-root}%{indep-libdir}/systemd/system-preset" \
      80-incus.preset

  # Create the incus / incus-admin groups at boot via sysusers.d.
  - |
    install -Dm644 incus-sysusers.conf \
      "%{install-root}%{indep-libdir}/sysusers.d/incus.conf"

  # Runtime/state dirs (tmpfiles) and kernel modules (modules-load).
  - |
    install -Dm644 incus-tmpfiles.conf \
      "%{install-root}%{indep-libdir}/tmpfiles.d/incus.conf"
    install -Dm644 incus-modules.conf \
      "%{install-root}%{indep-libdir}/modules-load.d/incus.conf"

  # Daemon environment (INCUS_EDK2_PATH for VM firmware).
  - |
    install -Dm644 default-incus "%{install-root}%{sysconfdir}/default/incus"

  # Default root idmap range for unprivileged containers.
  # NOTE: useradd adds per-user subids at account creation; this only seeds
  # the `root` range incusd needs. VALIDATE no conflict with the junction's
  # shadow/useradd config that also manages /etc/subuid.
  - |
    install -Dm644 subuid "%{install-root}%{sysconfdir}/subuid"
    install -Dm644 subgid "%{install-root}%{sysconfdir}/subgid"

  - |
    %{install-extra}

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
- kind: local
  path: files/incus/subuid
- kind: local
  path: files/incus/subgid
