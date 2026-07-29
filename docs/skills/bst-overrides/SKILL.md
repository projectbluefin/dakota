---
name: bst-overrides
description: Governs when and how to create junction overrides in Dakota. Upstream-first principle — local overrides are last resort. Use when deciding whether to override gnome-build-meta or freedesktop-sdk content.
---

# BST Junction Overrides

## Overview

Dakota inherits most elements from `gnome-build-meta` (GBM) and `freedesktop-sdk` (fdsdk) via BST junctions. Local overrides replace specific upstream elements with Dakota-local versions. They are maintenance debt and require an exit condition.

## When to use

- Deciding whether a local override is justified vs. a junction bump
- Adding a temporary junction override when upstream cannot fix in time
- Removing override debt after upstream catches up

## When not to use

- Full patch lifecycle after deciding to override → [patch-junctions](../patch-junctions/SKILL.md)
- Routine package updates in Dakota-owned elements → [update-refs](../update-refs/SKILL.md)
- Generic BST syntax → [buildstream](../buildstream/SKILL.md)

## Authoritative sources

- `elements/freedesktop-sdk.bst` — fdsdk junction with `patch_queue` and `overrides:` block
- `elements/gnome-build-meta.bst` — GBM junction with `patch_queue` and `overrides:` block
- `patches/freedesktop-sdk/` — fdsdk patch queue (applied alphabetically by filename)
- `patches/gnome-build-meta/` — GBM patch queue

## Workflow

1. **Check upstream first**: is the fix already in the latest junction ref? If yes, bump the ref instead.
2. **Submit upstream**: if the fix is appropriate for upstream, open an MR there and add a temporary local patch with an exit condition comment.
3. **Override locally only as last resort**: when upstream cannot or will not fix in time.
4. **Record exit condition**: every override or patch file must state when it can be removed.
5. **Re-evaluate on every junction bump**: when the junction ref advances, check whether each override is still needed.

### Override mechanisms

**Patch queue** (preferred for upstreamable changes):

```yaml
# In elements/freedesktop-sdk.bst
sources:
- kind: git_repo
  ...
- kind: patch_queue
  path: patches/freedesktop-sdk
```

Patches apply in alphabetical filename order. Gaps in numbering (e.g. 0001, 0002, 0004) are intentional — they leave room for insertions without renaming.

**Element override** (in the junction's `config: overrides:` block):

```yaml
config:
  overrides:
    components/foo.bst: bluefin/foo-override.bst
```

Use when completely replacing an upstream element with a Dakota-specific version.

### Exit condition format

Every patch or override must include:

```yaml
# Exit condition: Drop after fdsdk ships release X
# Exit condition: Drop once GBM gnome-50 merges MR !NNN
# Exit condition: Permanent — dakota-specific, not upstreamable
```

## Failure modes

- **Override surviving multiple junction bumps without re-evaluation**: the patch may now conflict or be redundant. Always check patch applicability when bumping junction refs.
- **Direct edits to junction `.bst` files**: do not edit the junction source content directly. Use `patch_queue` or `overrides:` block.

## Verification

```bash
just bst show oci/bluefin.bst    # graph validates with overrides applied
grep -r "Exit condition" patches/  # all overrides have documented exit paths
```

## Related skills

- [patch-junctions](../patch-junctions/SKILL.md) — full patch lifecycle workflow
- [buildstream](../buildstream/SKILL.md) — element syntax reference
- [update-refs](../update-refs/SKILL.md) — when a junction bump suffices
