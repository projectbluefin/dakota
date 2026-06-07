---
name: buildstream-reference
description: Reference for BuildStream 2 element syntax, variables, kinds, source kinds, and command hooks. Load when writing or reviewing .bst element files, not for end-to-end packaging workflows (use add-package.md for that).
---

# BuildStream Element Reference

Load when writing, editing, or reviewing BuildStream `.bst` element files.

## When NOT to Use

- End-to-end workflow for adding a new package → `add-package.md`
- Diagnosing build failures → `debugging.md`
- Understanding the CI pipeline → `ci.md`
- Managing junction overrides → `bst-overrides.md`

## Quick Recipes

| Goal | Command |
|------|---------|
| Validate full element graph (no build) | `just validate` |
| Inspect single element deps | `just bst show bluefin/<name>.bst` |
| Build one element | `just bst build bluefin/<name>.bst` |
| Enter build sandbox | `just bst shell --build bluefin/<name>.bst` |
| Track a git/tarball ref | `just bst source track bluefin/<name>.bst` |
| List built element contents | `just bst artifact list-contents bluefin/<name>.bst` |
| View build log | `just bst artifact log bluefin/<name>.bst` |
| Delete cached build | `just bst artifact delete bluefin/<name>.bst` |
| Full image build | `just build` |
| All available recipes | `just --list` |

## Variables

| Variable | Expands To | Notes |
|----------|-----------|-------|
| `%{install-root}` | Staging directory | Always prefix install paths with this |
| `%{prefix}` | `/usr` | |
| `%{bindir}` | `/usr/bin` | |
| `%{indep-libdir}` | `/usr/lib` | For systemd units, presets, sysusers, tmpfiles |
| `%{datadir}` | `/usr/share` | |
| `%{sysconfdir}` | `/etc` | Rarely used in GNOME OS elements |
| `%{install-extra}` | Empty hook | Convention: always end install-commands with this |
| `%{go-arch}` | `amd64`/`arm64`/`riscv64` | Defined in project.conf per-arch |
| `%{arch}` | `x86_64`/`aarch64`/`riscv64` | Raw architecture name |
| `strip-binaries` | Set to `""` to disable | Required for non-ELF elements (fonts, configs, pre-built) |
| `overlap-whitelist` | `public: bst: overlap-whitelist:` | List of paths allowed to overlap between elements |

## Element Kinds

| Kind | Use Case |
|------|----------|
| `manual` | Custom build/install, pre-built binaries, config files |
| `meson` | GNOME libraries/apps |
| `make` | Makefile projects, Go with vendored deps |
| `autotools` | Legacy C projects |
| `make` + `cargo2` | Rust projects (see `packaging-rust.md`) |
| `cmake` | CMake projects |
| `import` | Direct file placement (no build) |
| `stack` | Dependency aggregation, arch dispatch — **produces zero filesystem output** |
| `compose` | Layer filtering (exclude debug/devel) |
| `script` | OCI image assembly |
| `collect_initial_scripts` | Collect systemd preset/sysusers/tmpfiles from deps |

## Source Kinds

| Source Kind | Use Case |
|-------------|----------|
| `git_repo` | Most elements |
| `tar` | Release tarballs. Add `base-dir: ""` if tarball has no wrapping directory. |
| `remote` | Single file download (not extracted). Use `directory:` to place into a subdirectory. |
| `local` | Files from repo's `files/` directory |
| `cargo2` | Rust crate vendoring. Generate with `files/scripts/generate_cargo_sources.py`. |
| `go_module` | Go module deps (one per dep) |
| `git_module` | Git submodule checkout |
| `patch_queue` | Apply patches directory |
| `gen_cargo_lock` | Generate Cargo.lock from base64 |

## Command Hooks

| Syntax | Meaning |
|--------|---------|
| `(>):` | Append to inherited command list from element kind |
| `(<):` | Prepend to inherited command list |
| `(@):` | Include a YAML file |
| `(?):` | Conditional block (evaluates options like `arch`) |

Convention: always end `install-commands` with `%{install-extra}`.

## BST Weak-Key Caching Bug

**Symptom:** Adding a new package to `deps.bst` (`kind: stack`) does NOT trigger a rebuild of downstream OCI image layers (`kind: compose`). New package is missing from the final image even though `bst show` lists it.

**Root cause:** In BST non-strict mode, the "weak key" for a `kind: stack` element is computed from its **direct dependency names only**, not their content hashes. Changing what a `compose` element transitively depends on via a stack does not change the compose element's weak key → BST considers it cache-hit → skips rebuild.

**Workaround:** Force-invalidate the cache of a `kind: compose` element that directly depends on the stack by making any content change to one of its direct dependencies.

**Real fix:** Use `bst build` in strict mode: `just bst --no-cache-buildtrees build oci/bluefin.bst`.

## ECL / Common Lisp Packaging

| Fact | Detail |
|---|---|
| Must use `-std=gnu99` | ECL's `fpe_x86.c` uses bare `asm()` — invalid under `-std=c99` |
| Must use `--with-gmp=/usr` | Without this, ECL bundles its own GMP and propagates `-fasm` which breaks configure |
| `ecl --load` spawns `gcc` | Any element calling `ecl --load` at build time needs `gcc` in `build-depends` |
| `gitlab.common-lisp.net` sources | BST's dulwich cannot parse this git protocol — use `kind: tar` with GitLab archive URL |

## Lessons Learned

### Option names cannot contain hyphens (2026-06-07)

BST option names only allow alphanumeric characters and underscores. A name like `my-option` silently fails or causes a parse error. Use `my_option` instead. This trips up agents that copy option names from CLI flags (which typically use hyphens).

```yaml
# ❌ wrong
options:
  my-arch:
    type: arch

# ✅ correct
options:
  my_arch:
    type: arch
```

### `(>):` append syntax replaces the entire command list if used incorrectly (2026-06-07)

The `(>):` syntax appends to the inherited command list from the element kind. If you write it as a key at the wrong indent level, BST silently ignores it and uses only your commands, dropping the kind's built-in build steps. Always verify the final command list with `just bst show --format '%{name}: %{build-commands}' bluefin/<name>.bst` before building.

### `kind: stack` elements produce no filesystem output — they are dep aggregators only (2026-06-07)

`deps.bst` is intentionally `kind: stack`. That means it has zero filesystem output. Only `kind: compose` and `kind: script` elements produce filesystem artifacts. If a new layer element is accidentally typed as `kind: stack`, it will build successfully but the image layer will be empty. Always verify with `grep '^kind:' elements/oci/layers/bluefin.bst`.
