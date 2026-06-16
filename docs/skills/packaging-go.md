---

name: packaging-go
description: Packages a Go project from source using BST go_module sources or a vendored GOPATH tarball. Note: all current Go tools in Dakota use pre-built binaries — load packaging-binaries.md first to confirm source build is truly needed.
metadata:
  context7-sources:
    - /apache/buildstream
---

# Packaging Go Projects

Load when packaging a Go project for dakota/Bluefin BuildStream, or when setting up GOPATH vendoring in BuildStream.

## When to Use

Use when a Go project truly needs a source build in Dakota and pre-built binaries are not the better path.

## When NOT to Use

- Rust project → `packaging-rust.md`
- Zig project → `packaging-zig.md`
- Pre-built binary → `packaging-binaries.md`

## Core Process

1. Confirm source packaging is actually needed.
2. Pick the vendoring pattern (`go_module` vs embedded GOPATH tarball).
3. Ensure the build is fully offline inside BST.
4. Validate the produced binary layout and runtime behavior.

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

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It's Go, so I can just let it download modules." | Not inside network-isolated BST builds. |
| "Source build is more pure, so always do that." | Dakota already prefers pre-built binaries for many Go tools when that is the lazier correct path. |
| "One vendoring strategy fits all Go projects." | Pick the smaller maintenance burden that actually matches the project. |

## Red Flags

- Network-dependent Go build steps
- Choosing source packaging without checking `packaging-binaries.md` first
- Missing vendored dependency material in the element sources
- Treating GOPATH/module layout as an implementation detail you can hand-wave

## Verification

- [ ] Source build was justified over binary packaging
- [ ] All Go deps are available offline in BST
- [ ] The chosen vendoring pattern matches the project
- [ ] The final staged binary layout is correct

## Lessons Learned

### All current Go tools in Dakota are pre-built binaries — not Go-from-source builds (2026-06-07)

As of June 2026, every Go-based tool in Dakota uses `kind: manual` with pre-built binaries
from GitHub Releases. `glow.bst`, `gum.bst`, and `fzf.bst` are all pre-built binary elements,
not Go source builds. See `packaging-binaries.md` for the pre-built pattern.

Go-from-source build infrastructure (this skill) exists for future use when a required tool
doesn't provide static binaries. Do not reach for this skill unless upstream truly has no
release binaries — pre-built is simpler and faster to maintain.

### Vendored GOPATH tarball requires a build host with Go to generate (2026-06-07)

Pattern 2 (vendored GOPATH tarball) requires running `go mod vendor` on the host to create
the tarball before the element can be written. Unlike cargo2 (where the generator script
reads from the source), the Go vendor tarball must be generated offline and uploaded
separately. Factor in this extra maintenance step when deciding between Pattern 1 and
Pattern 2 — Pattern 1 (go_module sources) is more maintainable long-term because refs
can be updated in-place.
