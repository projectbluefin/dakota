---

name: packaging-zig
description: Packages a Zig build system project from source. Covers two-stage cache population (zig fetch for HTTP deps, manual placement for git deps), DESTDIR pattern, and -Dcpu=baseline requirement. ghostty.bst is the reference implementation.
metadata:
  context7-sources:
    - /apache/buildstream
---

# Packaging Zig Projects

Load when packaging a project that uses the Zig build system for dakota/Bluefin BuildStream.

## When to Use

Use when a project is built with Zig and needs the Dakota offline-cache packaging pattern.

## When NOT to Use

- Rust/Cargo project → `packaging-rust.md`
- Go project → `packaging-go.md`
- Pre-built binary → `packaging-binaries.md`

## Core Process

1. Read `build.zig.zon` and identify every dependency.
2. Pre-stage all dependencies as sources.
3. Populate the Zig cache in the expected offline layout.
4. Build with the repo's known-good CPU/runtime flags.
5. Validate the installed binary and cache assumptions.

## Overview

Zig builds are network-isolated in BST. Dependencies declared in `build.zig.zon` must be
pre-fetched and provided as source entries. The real-world pattern (from `ghostty.bst`) uses
`kind: remote` sources staged under `zig-deps/`, followed by a two-stage build that populates
the Zig cache before calling `zig build`.

## Actual Pattern — From ghostty.bst

Dakota's Ghostty element is the reference implementation. It uses `bluefin/zig.bst` (a local
wrapper around fdsdk's Zig) and this two-stage cache approach:

```yaml
kind: manual

variables:
  strip-binaries: ""  # ghostty uses this; set when installing non-standard files

build-depends:
  - bluefin/zig.bst                              # or fdsdk:components/zig.bst
  - freedesktop-sdk.bst:components/pkg-config.bst
  - gnome-build-meta.bst:sdk/gtk.bst

depends:
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

sources:
  # Main source
  - kind: tar
    url: project_releases:1.3.1/project-1.3.1.tar.gz
    ref: sha256hex...

  # Each zig.zon HTTP dep: one kind: remote per dep, all staged under zig-deps/
  - kind: remote
    url: ghostty_deps:libxev-34fa50878aec6e5fa8f532867001ab3c36fae23e.tar.gz
    ref: sha256hex...
    directory: zig-deps

  # Git deps (can't be resolved via zig fetch) go under zig-deps-git/
  - kind: remote
    url: github_files:owner/repo/archive/sha.tar.gz
    ref: sha256hex...
    directory: zig-deps-git
```

**Build stage — populate cache, then build:**

```yaml
config:
  build-commands:
    # Stage 1: Populate ZIG_GLOBAL_CACHE_DIR from each HTTP dep tarball
    - |
      export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
      export ZIG_LIB_DIR="%{libdir}/zig"
      mkdir -p "$ZIG_GLOBAL_CACHE_DIR/p"
      for dep in zig-deps/*; do
        zig fetch --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" "$dep"
      done

    # Stage 2: Manually place git deps that zig fetch can't resolve
    - |
      export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
      # Each git dep must be placed at the exact hash path the build expects:
      local dest="$ZIG_GLOBAL_CACHE_DIR/p/<zig-hash>"
      mkdir -p "$dest"
      tar xf "zig-deps-git/<sha>.tar.gz" --strip-components=1 -C "$dest"

  install-commands:
    - |
      export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
      export ZIG_LIB_DIR="%{libdir}/zig"
      DESTDIR="%{install-root}" \
      zig build \
        --prefix /usr \
        --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" \
        -Doptimize=ReleaseFast \
        -Dcpu=baseline \
        -Dpie=true \
        install
    - '%{install-extra}'
```

## Generating Dependency Sources

No automated generator script exists (unlike `cargo2`). Manual process per dep:

1. Get the URL from `build.zig.zon`'s `dependencies:` block
2. Download and hash with `zig fetch`:
   ```bash
   zig fetch --global-cache-dir /tmp/zig-cache <url>
   ```
3. Add as `kind: remote` source with `directory: zig-deps`
4. For git deps referenced as `git+https://...`, download the commit tarball and stage under `zig-deps-git/`

## Offline Build Flags

| Flag | Purpose |
|------|---------|
| `--global-cache-dir` | Override Zig global cache (required for reproducibility) |
| `-Doptimize=ReleaseFast` | Max optimization; use `ReleaseSafe` for safety-critical code |
| `-Dcpu=baseline` | Don't use host-CPU extensions — produces portable binaries |
| `-Dpie=true` | Position-independent executable (security hardening) |

**Note:** Use `DESTDIR="%{install-root}"` with `--prefix /usr` (not `--prefix "%{install-root}/usr"`).
The Zig build system applies `DESTDIR` correctly — `--prefix` must be the final install path.

## Using fdsdk's Zig vs. Local Wrapper

| Option | When |
|--------|------|
| `bluefin/zig.bst` | Dakota's current approach — local wrapper that pins Zig version |
| `freedesktop-sdk.bst:components/zig.bst` | When fdsdk ships a compatible version |

Check required Zig version in `build.zig.zon`:
```bash
grep minimum_zig_version path/to/build.zig.zon
```

## Checklist

- [ ] All `build.zig.zon` dependencies provided as BST sources
- [ ] HTTP deps staged under `directory: zig-deps`
- [ ] Git deps staged under `directory: zig-deps-git` with manual placement in build commands
- [ ] Zig version compatibility confirmed
- [ ] `DESTDIR` used with `--prefix /usr` (not `--prefix "%{install-root}/usr"`)
- [ ] `-Dcpu=baseline` set for portable binary
- [ ] Element added to `elements/bluefin/deps.bst`
- [ ] `just validate` passes
- [ ] `just bst build bluefin/<name>.bst` passes

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Zig will fetch dependencies for me during build." | Not inside BST. You must stage them. |
| "If one cache trick worked once, it'll generalize." | Zig dependency shapes vary; read the project first. |
| "The reference element is overkill." | The reference exists because ad-hoc Zig packaging breaks easily. |

## Red Flags

- Unstaged `build.zig.zon` dependencies
- Guessing cache layout instead of matching the reference pattern
- Skipping the repo's proven Zig flags
- Treating network isolation as an afterthought

## Verification

- [ ] All Zig deps are staged as sources
- [ ] Offline cache population is explicit and reproducible
- [ ] Build flags follow the known-good Dakota pattern
- [ ] Final binary layout was validated

## Lessons Learned

### git deps cannot be resolved by `zig fetch` — must be manually placed in cache (2026-06-07)

Zig dependencies declared as `git+https://...` in `build.zig.zon` cannot be fetched by
`zig fetch` from a tarball. `zig fetch` works for HTTP tarballs and archives with a content
hash, but not for raw git URLs. The solution: download the commit tarball (GitHub archive),
stage it under `zig-deps-git/`, and manually extract it into the Zig global cache at the
exact hash path the build expects:

```bash
local dest="$ZIG_GLOBAL_CACHE_DIR/p/<expected-zig-hash>"
mkdir -p "$dest"
tar xf "zig-deps-git/<commit-sha>.tar.gz" --strip-components=1 -C "$dest"
```

The expected `<zig-hash>` is the content-addressed hash Zig computes — it appears in
`build.zig.zon` as the `hash:` field for that dep. See `ghostty.bst` for the reference pattern.

### `DESTDIR + --prefix /usr` not `--prefix %{install-root}/usr` (2026-06-07)

Zig's build system respects the POSIX `DESTDIR` convention correctly. Use:
```bash
DESTDIR="%{install-root}" zig build --prefix /usr
```
Not:
```bash
zig build --prefix "%{install-root}/usr"
```
The second form bakes the staging path into installed file contents (e.g., .desktop files,
pkg-config `.pc` files), which breaks the final image.

### `-Dcpu=baseline` is required for cross-arch portable builds (2026-06-07)

Without `-Dcpu=baseline`, Zig detects and optimizes for the build host's CPU extensions
(AVX-512, etc.). The resulting binary may work on the build machine but crash on other
x86_64 hardware. Always set `-Dcpu=baseline` for Dakota builds to match fdsdk's portability
baseline.
