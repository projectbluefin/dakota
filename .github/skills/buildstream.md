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
| Validate element (dep graph, no build) | `just validate elements/bluefin/<name>.bst` |
| Build one element | `just bst build elements/bluefin/<name>.bst` |
| Enter build sandbox | `just bst shell --build elements/bluefin/<name>.bst` |
| Track a git ref | `just track-one elements/bluefin/<name>.bst` |
| Update tarball to new version | `just track-tarball elements/bluefin/<name>.bst <version>` |
| Scaffold binary element | `just scaffold-binary <name> <owner/repo>` |
| Scaffold GNOME extension | `just scaffold-gnome-ext <name> <owner/repo>` |
| Scaffold Rust element | `just scaffold-rust <name> <owner/repo>` |
| List reverse deps | `just reverse-deps elements/bluefin/<name>.bst` |
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

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
