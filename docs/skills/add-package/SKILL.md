---
name: add-package
description: End-to-end workflow for adding a new package to Dakota. Use when a task adds software, services, config-only elements, or new image content via BuildStream elements.
---

# Add a Package

## Overview

Dakota packages are BuildStream elements under `elements/bluefin/`. Adding a package means creating a `.bst` element, wiring it into the dependency stack (`elements/bluefin/deps.bst`), and validating the graph. There is no scaffold generator — copy a similar existing element.

## When to use

- Adding new software, services, or config-only elements to the image
- Wiring new content into `deps.bst`

## When not to use

- Removing a package → [remove-package](../remove-package/SKILL.md)
- Updating an existing version → [update-refs](../update-refs/SKILL.md)
- Debugging a failing build → [debugging](../debugging/SKILL.md)
- BST syntax reference only → [buildstream](../buildstream/SKILL.md)

## Authoritative sources

- `elements/bluefin/deps.bst` — the package manifest (`kind: stack`)
- `elements/bluefin/` — all package elements live here
- `include/aliases.yml` — source URL aliases
- `Justfile` — `bst`, `build`, `validate` recipes

## Workflow

1. Choose the correct element kind for the build system (see table below).
2. Copy a similar element: `cp elements/bluefin/glow.bst elements/bluefin/<name>.bst`
3. Edit the new element (sources, build/install commands, variables).
4. Add a source alias in `include/aliases.yml` if the download domain is new.
5. Wire the element into `elements/bluefin/deps.bst` (or `gnome-shell-extensions.bst`).
6. Validate: `just bst show oci/bluefin.bst`
7. Build: `just bst build bluefin/<name>.bst`

### Element kind selection

| Source type | Kind | Specialist skill |
|---|---|---|
| Pre-built binary/tarball | `manual` | [packaging-binaries](../packaging-binaries/SKILL.md) |
| Meson project | `meson` | — |
| Makefile project | `make` | — |
| Autotools project | `autotools` | — |
| CMake project | `cmake` | — |
| Rust/Cargo project | `make` + `cargo2` sources | [packaging-rust](../packaging-rust/SKILL.md) |
| Go project | `make` or `manual` + `go_module` | [packaging-go](../packaging-go/SKILL.md) |
| Zig project | `manual` + offline cache | [packaging-zig](../packaging-zig/SKILL.md) |
| GNOME Shell extension | extension layout | [packaging-gnome-extensions](../packaging-gnome-extensions/SKILL.md) |
| Config files only | `import` | — |

### Service installation

Enable services with preset files, never `systemctl enable`. Dakota is merged-usr: binaries go in `/usr/bin`, units in `%{indep-libdir}/systemd/system/`, presets in `%{indep-libdir}/systemd/system-preset/80-<name>.preset`. Patch upstream unit files to remove `/usr/sbin` and `EnvironmentFile=/etc/default/` references.

## Failure modes

- **Element builds but never lands in the image**: forgot to add it to `deps.bst`.
- **Strip phase fails on non-ELF payloads**: set `strip-binaries: ""` in the element's `variables:` block for fonts, config-only elements, or pre-stripped binaries.
- **Source URL fails to expand variables**: BST does not expand `%{version}` inside `sources[].url`. Use an alias from `include/aliases.yml` with a literal URL.

## Verification

```bash
just bst show oci/bluefin.bst        # graph validates
just bst build bluefin/<name>.bst    # element builds
grep '<name>' elements/bluefin/deps.bst  # wired into stack
```

## Related skills

- [buildstream](../buildstream/SKILL.md) — element syntax reference
- [oci-layers](../oci-layers/SKILL.md) — how layers compose into the final image
- [debugging](../debugging/SKILL.md) — when the build fails
