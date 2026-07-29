---
name: buildstream
description: BuildStream element syntax and mechanics reference for Dakota. Use when writing, reviewing, or validating .bst files and you need kinds, variables, source types, or graph commands.
---

# BuildStream Reference

## Overview

Dakota uses BuildStream 2 (BST) to define every package, layer, and the final OCI image as declarative `.bst` elements. This skill is the syntax and mechanics cheat sheet — not the end-to-end packaging workflow.

## When to use

- Choosing an element kind for a new or modified element
- Looking up standard variables, install paths, or source kinds
- Understanding graph validation and inspection commands

## When not to use

- End-to-end package addition → [add-package](../add-package/SKILL.md)
- Diagnosing a failing build → [debugging](../debugging/SKILL.md)
- Junction override strategy → [bst-overrides](../bst-overrides/SKILL.md)
- OCI layer assembly → [oci-layers](../oci-layers/SKILL.md)

## Authoritative sources

- `project.conf` — project options, sandbox config, variable defaults
- `include/aliases.yml` — all source URL aliases
- `elements/oci/bluefin.bst` — OCI assembly script (shows how layers compose)
- `elements/oci/layers/` — compose elements that produce filesystem layers
- `Justfile` — the `bst` recipe wraps all BST invocations

## Workflow

1. Validate the graph before building: `just bst show oci/bluefin.bst`
2. Build a single element: `just bst build bluefin/<name>.bst`
3. Enter the build sandbox: `just bst shell --build bluefin/<name>.bst`
4. Track a source ref: `just bst source track bluefin/<name>.bst`
5. Inspect built contents: `just bst artifact list-contents bluefin/<name>.bst`
6. View build log: `just bst artifact log bluefin/<name>.bst`
7. Delete cached artifact: `just bst artifact delete bluefin/<name>.bst`

### Element kinds

| Kind | Use case | Filesystem output? |
|---|---|---|
| `manual` | Custom build/install, pre-built binaries | Yes |
| `meson` | GNOME apps and libraries | Yes |
| `make` | Makefile projects | Yes |
| `autotools` | Legacy C projects | Yes |
| `cmake` | CMake projects | Yes |
| `import` | Direct file placement, no build | Yes |
| `compose` | Filesystem-producing layer/filter step | **Yes** |
| `stack` | Dependency aggregation only | **No** |
| `script` | OCI/image assembly | Yes |
| `junction` | External project boundary | N/A |

**Critical invariant**: an element staged at `/layer` in an OCI assembly script (like `elements/oci/bluefin.bst`) must be `kind: compose`. Using `kind: stack` there silently produces an empty layer because `stack` has zero filesystem output.

### Standard variables

| Variable | Expands to | Notes |
|---|---|---|
| `%{install-root}` | staging dir | Prefix all install paths |
| `%{prefix}` | `/usr` | Dakota is merged-usr |
| `%{bindir}` | `/usr/bin` | All binaries here |
| `%{indep-libdir}` | `/usr/lib` | systemd units, presets |
| `%{datadir}` | `/usr/share` | Data files |
| `%{sysconfdir}` | `/etc` | Use sparingly |
| `strip-binaries` | `""` to disable | Required for non-ELF payloads |

### Source kinds

| Kind | Use case |
|---|---|
| `git_repo` | Most source trees |
| `tar` | Release tarballs |
| `remote` | Single-file download |
| `local` | Repo-local files |
| `cargo2` | Rust crate vendoring (generated — never hand-edit) |
| `go_module` | Go module deps |
| `patch_queue` | Patch application on junctions |

### Command hook modifiers

| Syntax | Meaning |
|---|---|
| `(>):` | Append to inherited commands |
| `(<):` | Prepend to inherited commands |

## Failure modes

- **Option names with hyphens**: BST option names only allow alphanumeric and underscores. `my-option` silently fails; use `my_option`.
- **`overlap-whitelist` required for base-file replacement**: when an element provides files also provided by a junction component, declare the paths in `public: bst: overlap-whitelist:` to avoid composition errors.
- **Weak-key caching hides missing packages**: changing a `kind: stack` dependency does not always invalidate downstream `compose` outputs in non-strict mode. If a package is in the graph but missing from the image, delete the cached artifact and rebuild.

## Verification

```bash
just bst show oci/bluefin.bst          # full graph validates
just bst build bluefin/<name>.bst      # single element builds
just bst artifact list-contents bluefin/<name>.bst  # inspect output
```

## Related skills

- [add-package](../add-package/SKILL.md) — full packaging workflow
- [oci-layers](../oci-layers/SKILL.md) — layer composition details
- [bst-overrides](../bst-overrides/SKILL.md) — junction override mechanics
- [debugging](../debugging/SKILL.md) — build failure triage
