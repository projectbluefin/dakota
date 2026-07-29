---
name: packaging-go
description: Packages a Go project from source in Dakota's network-isolated BST sandbox using vendored modules. Load when adding or updating a Go-from-source element.
---

# Packaging Go Projects

## Overview

Go elements in Dakota use `kind: manual` with `go build -mod=vendor` inside a fully network-isolated BST sandbox. All module dependencies must be vendored into the source tree (either via an upstream release tarball that bundles `vendor/`, or by providing a `vendor/` directory as a separate source). There is no `go get` at build time.

Reference elements: `elements/bluefin/incus.bst` (CGO, release tarball with bundled vendor), `elements/bluefin/distrobox.bst` (pure Go, git source with vendor dir).

## When to use

- A Go project must be built from source and upstream does not ship usable pre-built binaries.
- The project requires CGO linking against Dakota-local libraries (e.g. Incus links cowsql/lxc).

## When not to use

- Upstream ships trusted static release binaries — use [packaging-binaries](../packaging-binaries/SKILL.md).
- The project is Rust or Zig — use [packaging-rust](../packaging-rust/SKILL.md) or [packaging-zig](../packaging-zig/SKILL.md).

## Authoritative sources

- `elements/bluefin/incus.bst` — CGO Go element with release-tarball vendor
- `elements/bluefin/distrobox.bst` — pure-Go element with git source + vendor dir
- `freedesktop-sdk.bst:components/go.bst` — the Go toolchain dependency
- `include/aliases.yml` — URL aliases for source downloads

## Workflow

1. Confirm upstream does not provide a usable pre-built binary (check GitHub Releases).
2. Determine the vendoring strategy:
   - **Release tarball** — upstream bundles `vendor/` in the release archive (preferred when available; see `incus.bst`).
   - **Separate vendor source** — provide a `vendor/` directory alongside the git source (see `distrobox.bst`).
3. Create the element under `elements/bluefin/<name>.bst` using `kind: manual`.
4. Add `freedesktop-sdk.bst:components/go.bst` as a build-depend. If CGO is needed, also add `freedesktop-sdk.bst:components/gcc.bst` and any required C libraries.
5. Set build commands with `-mod=vendor` (and `CGO_ENABLED=0` for static pure-Go binaries):
   ```yaml
   config:
     build-commands:
     - CGO_ENABLED=0 go build -mod=vendor -ldflags="-s -w" -o ./bin/name ./cmd/name
   ```
6. Install binaries to `%{install-root}%{bindir}/`.
7. Add the element to `elements/bluefin/deps.bst`.
8. Build: `just bst build bluefin/<name>.bst`.

## Failure modes

- **Missing vendor directory** — BST sandbox has no network; build fails immediately with module-not-found errors. Ensure `vendor/` is present via a tarball or git source that includes it.
- **CGO link failures** — if `CGO_ENABLED=1`, the C toolchain and all pkg-config libraries must be declared as build-depends.

## Verification

```bash
just bst build bluefin/<name>.bst
just bst shell bluefin/<name>.bst -- /usr/bin/<name> --version
```

## Related skills

- [packaging-binaries](../packaging-binaries/SKILL.md) — pre-built binary path (simpler when available)
- [add-package](../add-package/SKILL.md) — general element addition workflow
- [buildstream](../buildstream/SKILL.md) — BST element syntax reference
