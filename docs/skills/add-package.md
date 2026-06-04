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

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
