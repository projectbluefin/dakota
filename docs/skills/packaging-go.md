# Packaging Go Projects

Load when packaging a Go project for dakota/Bluefin BuildStream, or when setting up GOPATH vendoring in BuildStream.

## When NOT to Use

- Rust project → `packaging-rust.md`
- Zig project → `packaging-zig.md`
- Pre-built binary → `packaging-binaries.md`

## Go Build Approach in BST

BST builds are network-isolated (no `go get` at build time). Go modules must be vendored. Two patterns:

| Pattern | When |
|---------|------|
| `go_module` sources | Project uses Go modules; vendor each dep as a BST source |
| Embedded GOPATH tarball | Simpler; bundle all deps in a single tarball |

## Pattern 1: go_module Sources

```yaml
kind: make

build-depends:
- freedesktop-sdk.bst:components/go.bst
- freedesktop-sdk.bst:bootstrap-import.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  version: '1.2.3'
  gopath: /usr/lib/go

config:
  build-commands:
  - |
    export GOPATH="%{gopath}"
    export GOFLAGS="-mod=vendor"
    go build -o project ./cmd/project/

  install-commands:
  - install -Dm755 project "%{install-root}%{bindir}/project"
  - '%{install-extra}'

sources:
- kind: git_repo
  url: github:owner/project.git
  track: main
  ref: abc123...
- kind: go_module
  url: "github.com/some/dep"
  version: "v1.0.0"
  ref: sha256hex...
# ... one go_module entry per dependency
```

Generating `go_module` sources requires running `go mod vendor` on the project and converting `vendor/modules.txt`. See `files/scripts/generate_go_sources.py` if available.

## Pattern 2: Vendored GOPATH Tarball

Pre-vendor all dependencies locally and upload as a tarball:

```yaml
kind: manual

build-depends:
- freedesktop-sdk.bst:components/go.bst
- freedesktop-sdk.bst:bootstrap-import.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  version: '1.2.3'
  gopath: '%{build-root}/gopath'

sources:
- kind: git_repo
  url: github:owner/project.git
  ref: abc123...
  directory: project
- kind: tar
  url: alias:releases/owner/project/v%{version}/vendor.tar.gz
  ref: sha256hex...
  directory: vendor

install-commands:
- |
  cd project
  export GOPATH="%{gopath}"
  export GOFLAGS="-mod=vendor"
  go build -o "%{install-root}%{bindir}/project" ./cmd/project/
- '%{install-extra}'
```

## systemd Service (if needed)

```yaml
install-commands:
  # ... install binary ...
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system/project.service" <<'SERVICE'
    [Unit]
    Description=Project daemon
    After=network.target

    [Service]
    ExecStart=/usr/bin/project
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
    SERVICE
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system-preset/80-project.preset" <<'PRESET'
    enable project.service
    PRESET
```

## Checklist

- [ ] Go build is network-isolated (all deps in sources)
- [ ] `GOFLAGS="-mod=vendor"` set in build commands
- [ ] Binary installs to `%{bindir}` (not `/usr/sbin`)
- [ ] `strip-binaries: ""` not needed (Go binaries are ELF and strip cleanly)
- [ ] Element added to `elements/bluefin/deps.bst`
- [ ] `just validate` passes
- [ ] `just bst build bluefin/<name>.bst` passes

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
