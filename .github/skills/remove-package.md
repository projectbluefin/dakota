# Removing a Package

Load when removing a software package from the Bluefin image in `projectbluefin/dakota`.

## When NOT to Use

- Adding a package → `add-package.md`
- Only updating a version → `update-refs.md`
- Debugging a broken element → `debugging.md`

## Quick Start

```bash
just remove-package <name>
```

This command prints the full checklist of every file and reference to clean up. **Do not skip it — run it first.**

## What to Remove

| Item | Location |
|---|---|
| Element file | `elements/bluefin/<name>.bst` (or `elements/bluefin/shell-extensions/<name>.bst`) |
| Dependency entry | `elements/bluefin/deps.bst` (or `elements/bluefin/gnome-shell-extensions.bst`) |
| Static files | `files/<name>/` — delete entire directory if package-specific |
| Patches | `patches/<name>/` — delete entire directory if package-specific |
| Alias | `include/aliases.yml` — remove if the URL alias is no longer used by any other element |
| Tracking entry | `.github/workflows/track-bst-sources.yml` — remove from tracking matrix |
| Renovate entry | `.github/renovate.json5` — remove if tracked there |
| Justfile recipes | Remove or update any recipes referencing the package |

## Checklist (run after `just remove-package <name>`)

```bash
# Verify no dangling references
grep -r "<name>" elements/ .github/workflows/ files/ patches/ Justfile include/
# Validate dependency graph
just bst show oci/bluefin.bst
# Build image to confirm clean
just build
```

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
