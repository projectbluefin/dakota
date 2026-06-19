---
name: add-package
description: End-to-end workflow for adding a new package to Dakota. Use when a task adds software, services, config-only elements, or new image content via BuildStream elements.
metadata:
  context7-sources:
    - /apache/buildstream
---

# Add a Package

## Overview

This skill is the **end-to-end path** for new Dakota packages.
Use it after `not-bluefin.md` has reset the repo model.

## When to Use

Use when you need to:
- add a new package to the image
- add a new service or preset shipped by a package
- add a config-only/import element
- wire new software into `deps.bst`

## When NOT to Use

- Remove an existing package → `remove-package.md`
- Update an existing package version → `update-refs.md`
- Debug a failing build → `debugging.md`
- Need only BST syntax or element-kind reference → `buildstream.md`

## Core Process

1. **Pick the right element kind.**
2. **Copy a similar element as the starting point.** There is no scaffold generator.
3. **Create the new element under `elements/bluefin/`.**
4. **Wire it into the correct stack** (usually `elements/bluefin/deps.bst`).
5. **Add a source alias if the download domain is new.**
6. **Validate the graph before building.**
7. **Build the element, then the full image if needed.**

## Quick Start

```bash
cp elements/bluefin/glow.bst elements/bluefin/<name>.bst
# edit the new element
just bst show oci/bluefin.bst
just bst build bluefin/<name>.bst
```

## Choose Element Kind

| Source type | BuildStream kind | Next skill |
|---|---|---|
| Pre-built binary/tarball | `manual` + tar/remote source | `packaging-binaries.md` |
| Meson project | `meson` | — |
| Makefile project | `make` | — |
| Autotools project | `autotools` | — |
| CMake project | `cmake` | — |
| Rust/Cargo project | `make` + `cargo2` sources | `packaging-rust.md` |
| Go project | `make` or `manual` + `go_module` | `packaging-go.md` |
| Zig project | `manual` + offline cache | `packaging-zig.md` |
| GNOME Shell extension | extension-specific layout | `packaging-gnome-extensions.md` |
| Config files only | `import` | — |

## Service Installation Rules

Enable services with **preset files**, never `systemctl enable`.

| What | Where | Rule |
|---|---|---|
| service unit | `%{indep-libdir}/systemd/system/` | patch `/usr/sbin` → `/usr/bin`; remove `/etc/default/*` usage |
| preset file | `%{indep-libdir}/systemd/system-preset/80-<name>.preset` | `enable <service>.service` |
| binaries | `%{bindir}` | merged-usr means `/usr/bin`, not `/usr/sbin` |

```yaml
install-commands:
  - |
    sed -e 's|/usr/sbin/tailscaled|/usr/bin/tailscaled|g' \
        -e '/^EnvironmentFile=/d' \
        upstream.service > upstream.service.patched
    install -Dm644 -t "%{install-root}%{indep-libdir}/systemd/system" upstream.service.patched
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system-preset/80-name.preset" <<'PRESET'
    enable service-name.service
    PRESET
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Forgot `strip-binaries: ""` for non-ELF payloads | disable stripping in `variables:` |
| Used `/usr/sbin` or `/lib` | merged-usr means `/usr/bin` and `/usr/lib` |
| Left `EnvironmentFile=/etc/default/...` in unit | remove it |
| Used variables in `sources[].url` | use literal URLs plus aliases |
| Forgot to add the element to `deps.bst` | package builds but never lands in the image |
| Tried to solve it in `Containerfile` or `Justfile` | package/image-content changes belong in `.bst` + stack wiring |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just copy a package in through the Containerfile." | Wrong layer. The image graph is owned by BST. |
| "The element builds, so I'm done." | Not if it never got wired into the stack. |
| "Upstream service files are probably fine as-is." | Dakota repeatedly trips on `/usr/sbin` and `/etc/default` assumptions. |
| "I can skip graph validation and let CI tell me." | Local graph checks are cheaper than burning CI time. |

## Red Flags

- New package file exists but `deps.bst` was not touched
- Unit files install into old FHS paths
- Source URLs use fake variable expansion
- The plan mentions Containerfile or RPM steps

## Verification

- [ ] New element exists under `elements/bluefin/`
- [ ] Correct stack file was updated
- [ ] New source alias was added if needed
- [ ] `just bst show oci/bluefin.bst` passes
- [ ] The element builds successfully
- [ ] Service/preset files follow merged-usr and preset rules

## Lessons Learned

### `strip-binaries: ""` is required for all non-ELF staging directories (2026-06-07)

BST's default behavior calls `strip` on every binary in the staging area. If an element installs any file that is not a valid ELF binary (fonts, config files, shell scripts, pre-built tarballs, .so stubs), the build fails at the strip step with an obscure error. Always set `strip-binaries: ""` in the element's `variables:` block for:
- Font elements (`.ttf`, `.otf`, `.woff2`)
- Config-only elements (`kind: import`)
- Pre-built binary elements where upstream provides already-stripped binaries
- Any element where `file -b <binary>` returns something other than `ELF`

```yaml
variables:
  strip-binaries: ""
```

### BST variables cannot be used in source URL fields (2026-06-07)

Unlike install commands where `%{version}` expands correctly, BuildStream does NOT expand variables inside `sources[].url:` fields. Use `include/aliases.yml` to define a URL alias, then reference the alias.
