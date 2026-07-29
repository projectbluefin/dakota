---
name: packaging-gnome-extensions
description: Packages GNOME Shell extensions for Dakota's BuildStream image. Load when adding, updating, or debugging a GNOME Shell extension element.
---

# Packaging GNOME Shell Extensions

## Overview

GNOME Shell extensions live under `elements/bluefin/shell-extensions/` and are aggregated by `elements/bluefin/gnome-shell-extensions.bst` (a `kind: manual` element that depends on all individual extensions). Extensions use various build systems — `kind: meson` (app-indicators), `kind: make` (blur-my-shell), or `kind: manual` (disable-ext-validator) — but all share the UUID-based install path and require `strip-binaries: ""` since their payloads are JavaScript, not ELF.

Extension enablement and default settings are managed via a GSettings schema override installed by `elements/bluefin/shell-extensions/disable-ext-validator.bst`.

## When to use

- Adding a new GNOME Shell extension to Dakota.
- Updating an existing extension's source ref or version.
- Debugging extension enablement or schema override issues.

## When not to use

- Packaging a normal application (not a Shell extension).
- Working on dconf/GSettings unrelated to extensions.

## Authoritative sources

- `elements/bluefin/shell-extensions/` — all individual extension elements
- `elements/bluefin/gnome-shell-extensions.bst` — the extension aggregator
- `elements/bluefin/shell-extensions/disable-ext-validator.bst` — schema override with enabled-extensions list

## Workflow

1. Discover the extension UUID from `metadata.json` in the extension's source repo.
2. Create the element at `elements/bluefin/shell-extensions/<name>.bst`. Copy an existing element with a similar build system as the starting point.
3. Set `variables: strip-binaries: ""`.
4. Ensure the extension installs to the UUID path: `%{datadir}/gnome-shell/extensions/<uuid>/`.
5. If the extension has GSettings schemas, compile them in-element:
   ```yaml
   glib-compile-schemas --strict "%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}/schemas"
   ```
6. Add the element as a dependency in `elements/bluefin/gnome-shell-extensions.bst`.
7. Add the extension UUID to the `enabled-extensions` list in `elements/bluefin/shell-extensions/disable-ext-validator.bst`.
8. Build: `just bst build bluefin/shell-extensions/<name>.bst`.

## Failure modes

- **Wrong install path** — the UUID must be exact (case-sensitive, includes `@domain`). Verify from `metadata.json`, never guess from the project name.
- **Added to `deps.bst` instead of `gnome-shell-extensions.bst`** — extensions must be wired through the extension aggregator, not the general deps stack.
- **Schema override ordering** — the `enabled-extensions` key in the override file is a single GSettings value; it is last-writer-wins alphabetically. All extensions must appear in one override file (currently `zz3-bluefin-unsupported-stuff.gschema.override`).

## Verification

```bash
just bst build bluefin/shell-extensions/<name>.bst
just bst build bluefin/gnome-shell-extensions.bst
```

## Related skills

- [add-package](../add-package/SKILL.md) — general element addition workflow
- [buildstream](../buildstream/SKILL.md) — BST element syntax reference
- [oci-layers](../oci-layers/SKILL.md) — how extensions land in the final image
