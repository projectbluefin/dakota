---
name: packaging-zig
description: Packages a Zig build-system project from source using offline cache population in Dakota's network-isolated BST sandbox. Load when adding or updating a Zig element.
---

# Packaging Zig Projects

## Overview

Zig elements use `kind: manual` with a multi-stage build that pre-populates the Zig package cache before calling `zig build`. All dependencies declared in `build.zig.zon` must be provided as `kind: remote` sources staged into a local directory, then fed to the cache via `zig fetch` (for HTTP deps) or manual placement (for git deps).

Reference element: `elements/bluefin/ghostty.bst` (36 remote dep sources, two-stage cache).
Zig toolchain element: `elements/bluefin/zig.bst` (pre-built binary from ziglang.org).

## When to use

- A project uses the Zig build system and must be built from source in Dakota.
- The project has dependencies declared in `build.zig.zon`.

## When not to use

- Upstream ships trusted release binaries — use [packaging-binaries](../packaging-binaries/SKILL.md).
- The project is Rust or Go — use [packaging-rust](../packaging-rust/SKILL.md) or [packaging-go](../packaging-go/SKILL.md).

## Authoritative sources

- `elements/bluefin/ghostty.bst` — canonical Zig element (full pattern)
- `elements/bluefin/zig.bst` — Zig toolchain (pre-built binary element)
- `include/aliases.yml` — URL aliases (e.g. `ghostty_deps:`, `ziglang:`)

## Workflow

1. Read `build.zig.zon` from the project source to enumerate all dependencies.
2. Create the element under `elements/bluefin/<name>.bst` with `kind: manual`.
3. Add `bluefin/zig.bst` as a build-depend (provides `zig` binary and `lib/`).
4. Add one `kind: remote` source per HTTP dependency, staged into a `zig-deps/` directory. For git-only dependencies, stage them into a separate `zig-deps-git/` directory.
5. Write the build commands in three stages:
   - **Stage 1** — Create cache directory:
     ```yaml
     - |
       export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
       export ZIG_LIB_DIR="%{libdir}/zig"
       mkdir -p "$ZIG_GLOBAL_CACHE_DIR/p"
     ```
   - **Stage 2** — Populate cache from HTTP deps via `zig fetch`:
     ```yaml
     - |
       export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
       export ZIG_LIB_DIR="%{libdir}/zig"
       for dep in zig-deps/*; do
         zig fetch --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" "$dep"
       done
     ```
   - **Stage 3** — Place git deps manually by their Zig content hash:
     ```yaml
     - |
       export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
       place_git_dep() {
         local tarball="$1" zig_hash="$2"
         mkdir -p "$ZIG_GLOBAL_CACHE_DIR/p/$zig_hash"
         tar xf "$tarball" --strip-components=1 -C "$ZIG_GLOBAL_CACHE_DIR/p/$zig_hash"
       }
       place_git_dep "zig-deps-git/COMMIT.tar.gz" "package-name-HASH"
     ```
6. Write install commands using `DESTDIR` + `zig build`:
   ```yaml
   install-commands:
   - |
     DESTDIR="%{install-root}" zig build --prefix /usr \
       --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" \
       -Doptimize=ReleaseFast -Dcpu=baseline -Dpie=true
   ```
7. Set `variables: strip-binaries: ""` (Zig output includes non-ELF lib content).
8. Add the element to `elements/bluefin/deps.bst`.
9. Build: `just bst build bluefin/<name>.bst`.

## Failure modes

- **Missing `-Dcpu=baseline`** — Zig defaults to native CPU features, producing binaries that crash on older hardware. Always pass `-Dcpu=baseline`.
- **Git dep not manually placed** — `zig fetch` only resolves HTTP URLs; git-sourced transitive deps must be placed manually with the correct Zig content hash as the directory name.
- **Cache hash mismatch** — if `zig build` reports "hash mismatch", the tarball content changed upstream. Re-download and update the `ref:` SHA256 in the element.

## Verification

```bash
just bst build bluefin/<name>.bst
just bst shell bluefin/<name>.bst -- /usr/bin/<name> --version
```

## Related skills

- [packaging-binaries](../packaging-binaries/SKILL.md) — pre-built binary path
- [add-package](../add-package/SKILL.md) — general element addition workflow
- [buildstream](../buildstream/SKILL.md) — BST element syntax reference
