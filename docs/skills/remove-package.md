---

name: remove-package
description: Workflow for removing a software package from the Dakota image. Covers element deletion, deps.bst unwiring, dangling reference checks, and validation. Load for any "remove package from Dakota" task.
metadata:
  context7-sources:
    - /apache/buildstream
---

# Removing a Package

Load when removing a software package from the Dakota image in `projectbluefin/dakota`.

## When to Use

Use when deleting software from Dakota, unwiring an obsolete element, or removing image content that should no longer ship.

## When NOT to Use

- Adding a package → `add-package.md`
- Only updating a version → `update-refs.md`
- Debugging a broken element → `debugging.md`

## Core Process

1. Find every reference before deleting anything.
2. Remove the element and unwind stack wiring.
3. Check workflows, docs, presets, and ancillary references.
4. Validate the graph after the removal.
5. Confirm the image no longer carries the package.

## Quick Start

There is no `just remove-package` recipe. Remove packages manually using the checklist below.

**Historical path note:** packages still live under `elements/bluefin/` because
of repo history. Treat that as a path name only — removing software from Dakota
means editing BST elements and dependency stacks, not Containerfile or RPM
metadata.

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

## Checklist

```bash
# 1. Remove the element file
rm elements/bluefin/<name>.bst  # or shell-extensions/<name>.bst

# 2. Remove from dependency stack
# Edit elements/bluefin/deps.bst or gnome-shell-extensions.bst

# 3. Check for dangling references
grep -r "<name>" elements/ .github/workflows/ files/ patches/ Justfile include/

# 4. Remove any remaining files (static assets, patches, aliases)
# See table below

# 5. Validate dependency graph
just validate

# 6. Build image to confirm clean
just build
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just delete the element file and let CI find the rest." | Dakota removals usually leave dangling graph or workflow references. |
| "The `bluefin/` path means there may be an RPM side to clean up too." | No. Clean up BST wiring, not imaginary RPM metadata. |
| "If the build still works, the package is gone." | You still need to verify the image and references are actually clean. |

## Red Flags

- Element file deleted without touching `deps.bst` or other stacks
- No repo-wide reference search before removal
- Assuming package removal is local to one file
- Containerfile/RPM cleanup steps showing up in the plan

## Verification

- [ ] All references to the package were searched before deletion
- [ ] Stack wiring and ancillary references were removed
- [ ] The graph validates after removal
- [ ] The image/package output no longer includes the removed software

## Lessons Learned

### Grep all four locations before removing — elements/, workflows/, files/, Justfile (2026-06-07)

A package can be referenced in up to four separate places beyond the element file itself:
1. `elements/bluefin/deps.bst` (or gnome-shell-extensions.bst) — dependency stack entry
2. `.github/workflows/track-bst-sources.yml` — tracking matrix entry
3. `.github/renovate.json5` — Renovate config entry (if tracked there)
4. `files/<name>/` — static assets directory

Missing any of these causes a dangling reference. Always run:
```bash
grep -r "<name>" elements/ .github/workflows/ files/ patches/ Justfile include/
```
before opening the PR.

### `just validate` may pass even with a dangling dep entry (2026-06-07)

If you remove the element file but forget to remove it from `deps.bst`, `just validate`
exits successfully (BST resolves deps lazily from the graph — missing elements are only
caught at the `bst show --deps all` level). Always run `just bst show oci/bluefin.bst`
(not just `just validate`) to catch missing element references before committing.
