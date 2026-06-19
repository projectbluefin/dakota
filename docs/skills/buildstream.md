---
name: buildstream
description: BuildStream reference for Dakota element authors. Use when writing, reviewing, or validating `.bst` files and you need the correct kinds, variables, source types, hooks, or graph commands.
metadata:
  context7-sources:
    - /apache/buildstream
---

# BuildStream Reference

## Overview

This skill is the **syntax and mechanics reference** for Dakota's BuildStream work.
It is not the end-to-end packaging workflow; it is the cheat sheet for getting `.bst` files right.

## When to Use

Use when you need:
- element kinds and when they apply
- standard variables and install paths
- source kind guidance
- command-hook syntax
- graph validation or inspection commands

## When NOT to Use

- End-to-end package addition → `add-package.md`
- Diagnosing a failing build → `debugging.md`
- CI workflow behavior → CI skills
- Junction override strategy → `bst-overrides.md`

## Core Process

1. **Validate the graph before building.**
2. **Choose the correct element kind for the source/build system.**
3. **Use standard install variables and merged-usr paths.**
4. **Prefer existing repo patterns over invention.**
5. **Inspect single-element deps and artifacts before escalating to a full image build.**

## Quick Recipes

| Goal | Command |
|---|---|
| Validate full graph | `just bst show oci/bluefin.bst` |
| Inspect single element deps | `just bst show bluefin/<name>.bst` |
| Build one element | `just bst build bluefin/<name>.bst` |
| Enter build sandbox | `just bst shell --build bluefin/<name>.bst` |
| Track a source ref | `just bst source track bluefin/<name>.bst` |
| List built contents | `just bst artifact list-contents bluefin/<name>.bst` |
| View build log | `just bst artifact log bluefin/<name>.bst` |
| Delete cached build | `just bst artifact delete bluefin/<name>.bst` |

## Key Variables

| Variable | Expands to | Notes |
|---|---|---|
| `%{install-root}` | staging dir | prefix install paths with this |
| `%{prefix}` | `/usr` | Dakota is merged-usr |
| `%{bindir}` | `/usr/bin` | binaries go here |
| `%{indep-libdir}` | `/usr/lib` | systemd units, presets, tmpfiles, sysusers |
| `%{datadir}` | `/usr/share` | data files |
| `%{sysconfdir}` | `/etc` | use sparingly |
| `%{install-extra}` | trailing hook | convention: end install-commands with it |
| `strip-binaries` | set to `""` to disable | needed for non-ELF payloads |

## Element Kinds

| Kind | Use case |
|---|---|
| `manual` | custom build/install, pre-built binaries |
| `meson` | GNOME apps and libraries |
| `make` | Makefile projects |
| `autotools` | legacy C projects |
| `cmake` | CMake projects |
| `import` | direct file placement, no build |
| `stack` | dependency aggregation only; **produces no filesystem output** |
| `compose` | filesystem-producing layer/filter step |
| `script` | OCI/image assembly |
| `junction` | upstream source tree / external project boundary |

## Source Kinds

| Source kind | Use case |
|---|---|
| `git_repo` | most source trees |
| `tar` | release tarballs |
| `remote` | single-file download |
| `local` | repo-local files |
| `cargo2` | Rust crate vendoring |
| `go_module` | Go module deps |
| `patch_queue` | patch application |

## Command Hook Syntax

| Syntax | Meaning |
|---|---|
| `(>):` | append to inherited commands |
| `(<):` | prepend to inherited commands |
| `(@):` | include YAML |
| `(?):` | conditional block |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "`stack` and `compose` are basically the same." | No. `stack` aggregates deps only; `compose` produces filesystem output. |
| "I'll validate by building; same difference." | `bst show` catches graph/YAML problems faster and cheaper. |
| "Variables should expand in URLs too." | They do not. Use aliases. |
| "This path probably goes in `/usr/sbin`." | Dakota is merged-usr. Default to `/usr/bin`. |

## Red Flags

- `kind: stack` where filesystem output is expected
- source URLs using fake variable expansion
- install paths outside `/usr`
- no `%{install-root}` prefix in install commands
- building before the graph even shows cleanly

## Verification

- [ ] The chosen element kind matches the real build/input model
- [ ] The graph validates with `just bst show oci/bluefin.bst`
- [ ] Install paths use standard variables and merged-usr locations
- [ ] Any filesystem-producing layer uses `compose`, not `stack`
- [ ] Source and hook syntax follow repo conventions

## Lessons Learned

### Option names cannot contain hyphens (2026-06-07)

BST option names only allow alphanumeric characters and underscores. A name like `my-option` silently fails or causes a parse error. Use `my_option` instead. This trips up agents that copy option names from CLI flags (which typically use hyphens).

### Weak-key caching can hide new packages behind a clean build (2026-06-07)

Changing a `kind: stack` dependency does not always invalidate downstream `compose` outputs in non-strict mode. If a package is present in the graph but missing from the final image, inspect cache behavior before assuming the package element is wrong.
