---
name: not-bluefin
description: Mental-model reset — Dakota is BuildStream only, no dnf/RPM/Containerfile overlays. Load when your plan mentions dnf, RPM, COPR, spec files, or Containerfile package layers, or when bluefin habits are leaking into a Dakota task.
---

# Not Bluefin

## Overview

Dakota builds its OCI desktop image entirely from BuildStream elements. There is no `dnf install`, no RPM spec workflow, no COPR repo, and no Containerfile package-overlay step. Historical `bluefin/` path names in this tree (e.g. `elements/bluefin/`, `oci/bluefin.bst`) are Dakota build paths — they do not imply the separate bluefin repo's Containerfile/RPM workflow.

## When to use

- Your draft mentions `dnf`, RPM, COPR, `.spec`, or package repositories.
- You are about to change image contents and haven't yet identified the BST element.
- You see `elements/bluefin/*` and instinctively reach for bluefin's overlay workflow.
- You are onboarding into Dakota from another Project Bluefin repo.

## Translation table

| Bluefin habit | Dakota equivalent |
|---|---|
| `dnf install <pkg>` | Create or edit a `.bst` element in `elements/bluefin/` |
| Enable a COPR / third-party repo | Package from source via a BST element |
| Edit a Containerfile to add packages | Edit BST elements; image content comes from the build graph |
| RPM package name as source of truth | Upstream source tarball/git ref in the BST element is the truth |
| `bluefin/` path = bluefin process | `bluefin/` path = Dakota build path (legacy name only) |

## Failure modes

### Wrong-model PR

A PR that adds `dnf install` or edits a Containerfile to inject packages will never produce the intended result in Dakota. The image is assembled from BST artifact outputs — there is no package-manager step in the build pipeline.

### Confusing path names with process

`elements/bluefin/deps.bst` is Dakota's package manifest (`kind: stack`). It lists BST element dependencies, not RPM names. Treating it as an RPM manifest leads to searching for nonexistent spec files.

## Verification

```bash
# The package manifest is a BST stack, not an RPM list
head -5 elements/bluefin/deps.bst
# Expected: kind: stack

# No dnf/rpm commands exist in the build pipeline
grep -r "dnf\|rpm " elements/ | grep -v "^Binary"
# Expected: no results (or only comments/descriptions)
```

## Related skills

- [add-package](../add-package/SKILL.md) — correct flow for adding a package to Dakota
- [buildstream](../buildstream/SKILL.md) — BST element syntax and kinds
- [oci-layers](../oci-layers/SKILL.md) — how elements reach the final image
