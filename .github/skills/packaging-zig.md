# Packaging Zig Projects

Load when packaging a project that uses the Zig build system for dakota/Bluefin BuildStream.

## When NOT to Use

- Rust/Cargo project → `packaging-rust.md`
- Go project → `packaging-go.md`
- Pre-built binary → `packaging-binaries.md`

## Overview

Zig builds are network-isolated in BST. Dependencies declared in `build.zig.zon` must be pre-fetched and provided as source entries. The Zig compiler itself is available from freedesktop-sdk, or can be bootstrapped via a pre-built binary (see `packaging-binaries.md`).

## Element Structure

```yaml
kind: manual

build-depends:
- freedesktop-sdk.bst:components/zig.bst
- freedesktop-sdk.bst:bootstrap-import.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  version: '0.1.0'
  zig-cache: '%{build-root}/.zig-cache'
  install-prefix: '%{install-root}%{prefix}'

config:
  install-commands:
  - |
    zig build \
      --prefix "%{install-prefix}" \
      --cache-dir "%{zig-cache}" \
      --global-cache-dir "%{zig-cache}" \
      -Doptimize=ReleaseSafe \
      install
  - '%{install-extra}'

sources:
- kind: git_repo
  url: github:owner/project.git
  track: main
  ref: abc123...
# zig fetch dependencies (one remote or tar source per dep):
- kind: tar
  url: alias:releases/some-dep/0.1.0/dep.tar.gz
  ref: sha256hex...
  directory: zig-deps/dep
```

## Generating Dependency Sources

Zig dependencies (`build.zig.zon` `dependencies:` block) must be pre-fetched. For each dependency:

1. Get the URL from `build.zig.zon`
2. Download and hash it:
   ```bash
   zig fetch --global-cache-dir /tmp/zig-cache <url>
   ```
3. Add to element sources with the corresponding hash

No automated generator script exists yet (unlike `cargo2`). Manual work is required for each dep.

## Offline Build Flags

| Flag | Purpose |
|------|---------|
| `--cache-dir` | Per-project Zig cache |
| `--global-cache-dir` | Override global Zig cache location (required for reproducibility) |
| `-Doptimize=ReleaseSafe` | Optimized with safety checks |
| `-Doptimize=ReleaseFast` | Maximum optimization, no safety checks |
| `install` | Default install step |

Always set both `--cache-dir` and `--global-cache-dir` to controlled paths inside `%{build-root}`.

## Using fdsdk's Zig vs. Bootstrapped Zig

| Option | When |
|--------|------|
| `freedesktop-sdk.bst:components/zig.bst` | When fdsdk ships a compatible Zig version |
| Pre-built Zig binary (see `packaging-binaries.md`) | When the project requires a specific Zig version not in fdsdk |

Check the required Zig version in `build.zig.zon`:
```bash
# Look for minimum_zig_version field
grep minimum_zig_version path/to/build.zig.zon
```

## Checklist

- [ ] All `build.zig.zon` dependencies are provided as BST sources
- [ ] `--cache-dir` and `--global-cache-dir` point inside `%{build-root}`
- [ ] Zig version compatibility confirmed
- [ ] `strip-binaries: ""` not needed (Zig produces ELF)
- [ ] Element added to `elements/bluefin/deps.bst`
- [ ] `just validate` passes
- [ ] `just bst build bluefin/<name>.bst` passes

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
