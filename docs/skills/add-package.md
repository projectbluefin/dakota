---
name: add-package
description: End-to-end workflow for adding a new software package to the Dakota image. Covers element creation, deps.bst wiring, systemd service installation, and common mistakes. Load for any "add package to Dakota" task.
---

# Adding a Package

Entry-point workflow for adding any software package to the Dakota image.

## When NOT to Use

- Removing a package → `remove-package.md`
- Updating an existing package's version → `update-refs.md`
- Debugging a build failure → `debugging.md`
- BST variable/kind reference only → `buildstream.md`

## Agent Quick-Start

```bash
# Create element file manually at elements/bluefin/<name>.bst
# Use an existing element as a template, e.g.:
cp elements/bluefin/glow.bst elements/bluefin/<name>.bst
# Edit to match the new package's source and install paths
```

There are no scaffold scripts. Copy an existing element of the appropriate kind as a starting point.

**Historical path note:** new Dakota packages still live under
`elements/bluefin/` and are added to `elements/bluefin/deps.bst`. That path
name is historical only — do not translate package work into dnf, RPM, or
Containerfile-overlay steps.

## Choose Element Kind

| Source type | BuildStream kind | Sub-skill |
|---|---|---|
| Pre-built binary/tarball | `manual` + tar/remote source | `packaging-binaries.md` |
| Source with Meson build | `meson` | — |
| Source with Makefile | `make` | — |
| Source with autotools | `autotools` | — |
| Source with CMake | `cmake` | — |
| Rust/Cargo project | `make` + `cargo2` sources | `packaging-rust.md` |
| Go project | `make` or `manual` + GOPATH/go_module | `packaging-go.md` |
| Zig project | `manual` + offline cache | `packaging-zig.md` |
| GNOME Shell extension | `import`/`meson`/`make` + extension layout | `packaging-gnome-extensions.md` |
| Config files only | `import` | — |

## Workflow

1. **Create element** at `elements/bluefin/<name>.bst` (copy a similar existing element as a base)
2. **Add to deps** — add `bluefin/<name>.bst` to `depends:` in `elements/bluefin/deps.bst`
3. **Add source alias** — if the download domain is new, add an alias to `include/aliases.yml`
4. **Validate graph** — `just validate` (full graph check)
5. **Build element** — `just bst build bluefin/<name>.bst`
6. **Full image test** — `just build` or `just show-me-the-future`

## Systemd Service Installation

Services bundled with a package need three things:

| What | Where | Notes |
|---|---|---|
| Service file | `%{indep-libdir}/systemd/system/` | Patch `/usr/sbin` to `/usr/bin`; remove `EnvironmentFile=/etc/default/*` lines |
| Preset file | `%{indep-libdir}/systemd/system-preset/80-<name>.preset` | Content: `enable <service-name>.service` |
| Binaries | `%{bindir}` | Never `/usr/sbin` — GNOME OS uses merged-usr |

Enable services via preset files, never `systemctl enable`.

```yaml
install-commands:
  - |
    sed -e 's|/usr/sbin/tailscaled|/usr/bin/tailscaled|g' \
        -e '/^EnvironmentFile=/d' \
        upstream.service > upstream.service.patched
    install -Dm644 -t "%{install-root}%{indep-libdir}/systemd/system" upstream.service.patched
    mv "%{install-root}%{indep-libdir}/systemd/system/upstream.service.patched" \
       "%{install-root}%{indep-libdir}/systemd/system/upstream.service"
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system-preset/80-name.preset" <<'PRESET'
    enable service-name.service
    PRESET
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Missing `strip-binaries: ""` | Required for non-ELF elements — build fails otherwise |
| Using `/usr/sbin` | Always `/usr/bin` — GNOME OS merged-usr |
| `EnvironmentFile=/etc/default/...` | GNOME OS doesn't use `/etc/default/`; remove from upstream service files |
| Variables in source URLs | BuildStream doesn't support this; use literal URLs with aliases |
| Missing `%{install-extra}` | Must be last install-command |
| Trying to add the package in `Containerfile`/`Justfile` | Package and image-content changes belong in `.bst` elements plus `deps.bst` |
| Forgot to add element to `deps.bst` | Element builds but won't be in the image |
| Wrong dependency stack | Use `freedesktop-sdk.bst:public-stacks/runtime-minimal.bst` for runtime deps |

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

Unlike install commands where `%{version}` expands correctly, BuildStream does NOT expand variables inside `sources[].url:` fields. Use `include/aliases.yml` to define a URL alias, then reference the alias:

```yaml
# ❌ WRONG — variable expansion does not work in source URLs
sources:
- kind: tar
  url: https://github.com/owner/project/releases/v%{version}.tar.gz

# ✅ CORRECT — use an alias
sources:
- kind: tar
  url: alias:project-releases/v%{version}.tar.gz
  # alias defined in include/aliases.yml as:
  #   project-releases: https://github.com/owner/project/releases/
```

### Service preset files must use /usr/lib path, not /etc (2026-06-07)

Dakota is a GNOME OS-model image. Service preset files installed at `/etc/systemd/system-preset/` are ignored at boot. Presets must be at the `%{indep-libdir}` path:

```yaml
# ✅ correct
install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system-preset/80-name.preset"

# ❌ wrong — ignored at boot
install -Dm644 /dev/stdin "%{install-root}%{sysconfdir}/systemd/system-preset/80-name.preset"
```
