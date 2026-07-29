---
name: remove-package
description: Workflow for removing a software package from the Dakota image. Use when removing a package, service, shell extension, or other image content from Dakota.
---

# Remove a Package

## Overview

Removing a Dakota package means deleting the `.bst` element, unwiring it from the dependency stack, searching for all ancillary references, and validating the graph. There is no automated recipe — removals are manual and require a repo-wide grep.

## When to use

- Deleting software, services, or shell extensions from the image
- Unwiring an obsolete element from `deps.bst`

## When not to use

- Adding a package → [add-package](../add-package/SKILL.md)
- Updating a version → [update-refs](../update-refs/SKILL.md)
- Debugging a broken element → [debugging](../debugging/SKILL.md)

## Authoritative sources

- `elements/bluefin/deps.bst` — primary package stack
- `elements/bluefin/gnome-shell-extensions.bst` — extension stack
- `.github/workflows/track-bst-sources.yml` — tracking matrix
- `include/aliases.yml` — source URL aliases

## Workflow

1. Search for every reference to the package before deleting anything:
   ```bash
   grep -r "<name>" elements/ .github/workflows/ files/ patches/ Justfile include/
   ```
2. Delete the element file: `rm elements/bluefin/<name>.bst`
3. Remove the entry from `elements/bluefin/deps.bst` (or `gnome-shell-extensions.bst`).
4. Remove associated static files (`files/<name>/`), patches (`patches/<name>/`), alias entries, tracking-matrix entries, and Renovate entries as found by step 1.
5. Validate the full dependency graph:
   ```bash
   just bst show oci/bluefin.bst
   ```
6. Confirm the image no longer carries the package:
   ```bash
   just bst build oci/bluefin.bst
   ```

## Failure modes

- **Dangling dep entry not caught by `just validate`**: BST resolves deps lazily — a removed element file with a stale `deps.bst` entry only errors at `bst show --deps all` depth. Always use `just bst show oci/bluefin.bst` (which passes `--deps all`) rather than a shallow check.
- **Orphaned tracking-matrix entry**: causes a CI workflow error on the next scheduled track run if the element file no longer exists.

## Verification

```bash
just bst show oci/bluefin.bst                    # graph validates
grep -r "<name>" elements/ .github/workflows/    # no remaining references
```

## Related skills

- [add-package](../add-package/SKILL.md) — the inverse operation
- [buildstream](../buildstream/SKILL.md) — element syntax reference
