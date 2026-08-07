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
cp elements/bluefin/gum.bst elements/bluefin/<name>.bst
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
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-name.preset"
    cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-name.preset" <<'PRESET'
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

### CMake 4 rejects pre-3.5 policy versions; set a package-local floor (2026-08-02)

CMake 4 removed compatibility with policy versions older than 3.5, so pinned
releases whose `CMakeLists.txt` declares `cmake_minimum_required(VERSION 3.4)`
fail before configuration. If upstream has fixed the declaration but has not
published a newer release, use CMake's packager-facing compatibility variable
through the BuildStream CMake plugin's per-element `cmake-local` variable:

```yaml
variables:
  cmake-local: >-
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
```

Keep the override package-local; do not lower policy behavior globally. Prefer a
newer fixed upstream release when one exists, and remove the override after the
source bump. This follows the CMake 4.0 release notes' **Deprecated and Removed
Features** section and the official `CMAKE_POLICY_VERSION_MINIMUM` documentation.

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

### Ship WirePlumber policy as a `/usr/share` fragment (2026-07-31)

WirePlumber 0.5 loads distribution-provided configuration fragments from
`/usr/share/wireplumber/wireplumber.conf.d/*.conf`, while `/etc` and user
configuration directories remain higher-priority override locations. For
system-wide ALSA policy, add a config-only manual element with a local source,
install the fragment under that `/usr/share` path, and wire the element into
`elements/bluefin/deps.bst`. Use `monitor.alsa.rules` to match a device and
set `device.disabled = true` when the device must remain kernel-visible but
must not become a desktop PipeWire node.

### BST variables cannot be used in source URL fields (2026-06-07)

Unlike install commands where `%{version}` expands correctly, BuildStream does NOT expand variables inside `sources[].url:` fields. Use `include/aliases.yml` to define a URL alias, then reference the alias.

### lsp-plugins 1.1.x is self-contained; 1.2.x requires network module fetching (2026-06-21)

The `sadko4u/lsp-plugins` GitHub repo (redirects to `lsp-plugins/lsp-plugins`) switched to a modular
build system in the 1.2.x series that runs `make fetch` to download ~12 submodules at build time.
The 1.1.x series (latest: 1.1.26) is monolithic and BST-safe. Use 1.1.x for BST packaging.

Build LV2 only (no UI, no JACK, no standalone):

```yaml
variables:
  make-args: >-
    BUILD_MODULES=lv2
    LV2_UI=0
    BUILD_R3D_BACKENDS=
    PREFIX=%{prefix}
```

External dep: `freedesktop-sdk.bst:components/sndfile.bst`. No external LV2 headers needed — bundled.

### Dropping upstream apps silently drops their transitive libs/typelibs (2026-07-19)

`core/meta-gnome-core-apps.bst` is overridden to a short allow-list, so any library
pulled *only* by a dropped app never enters the image. This is invisible until a GI
consumer fails to bind it. Example: dakota#1022 — gnome-console/builder/foundry were
the only pullers of gnome-build-meta's `core-deps/vte.bst`, so the image shipped **zero**
VTE typelibs and the user-installed ddterm extension (GTK3 ABI, `Vte-2.91`) could not load.

Fix pattern: add a dedicated `bluefin/<lib>.bst` that rebuilds the *same source/ref as
the junction element* (keep them in lockstep — bump together) rather than overriding the
junction. If a Shell extension needs the GTK3 introspection ABI, build with `-Dgtk3=true`
(depends on `gnome-build-meta.bst:sdk/gtk+-3.bst`); upstream's VTE is GTK4-only. Push demo
binaries and unversioned `.so` linker symlinks to the `devel` split so `bluefin-runtime`'s
compose (which excludes `devel`) keeps only the `.typelib` + versioned `.so.N`.

### User services that require `/dev/uinput` need both module loading and uaccess (2026-07-31)

For a user-level daemon that opens `/dev/uinput`, installing the upstream unit
alone is insufficient. Ship a modules-load entry for `uinput` and a udev rule
with `TAG+="uaccess"` so the active desktop user receives device ACL access
without manual `chmod` or group edits. Keep the user unit present but unenabled
unless the feature is explicitly opt-in.
