# BST Junction Overrides

Load when creating, evaluating, or removing BuildStream junction element overrides in `projectbluefin/dakota`.

## Core Principle: Upstream-First

Dakota inherits most elements from `gnome-build-meta` (GBM) and `freedesktop-sdk` (fdsdk) via BST junctions. The correct workflow is always:

1. **Check if upstream already has the fix** — if yes, bump the junction ref
2. **Submit a fix upstream** — patch the upstream project, reference the upstream PR
3. **Override locally as a last resort** — only when upstream won't or can't fix in time

Local overrides are maintenance debt. Every override needs an exit condition.

## What Is a Junction Override?

By default, `elements/gnome-build-meta.bst` and `elements/freedesktop-sdk.bst` use the refs from the upstream junction. An override replaces a specific upstream element with a local version.

**Do NOT edit junction `.bst` files directly.** Overrides are applied via `patch_queue` source in the junction file, or by providing a local element that shadows the junction element.

## Override Patterns

### Patch Queue Override (Preferred)

For changes that should eventually go upstream, add a patch to the junction's `patch_queue`:

```yaml
# In elements/gnome-build-meta.bst
sources:
- kind: git_repo
  ...
- kind: patch_queue
  path: patches/gnome-build-meta
```

Patches in `patches/gnome-build-meta/` apply in alphabetical (filename) order. See `patch-junctions.md` for the full patch lifecycle.

### Element Shadow Override

To completely replace an upstream element, create a local element at the same path the junction would provide. Use sparingly.

## Evaluating Whether to Override

| Question | If yes → |
|---|---|
| Is the fix already in upstream's latest ref? | Bump junction ref instead |
| Will upstream accept a fix within the current cycle? | Submit PR upstream, add temporary patch with `Upstream-Status: Submitted` |
| Is this dakota-specific (not appropriate upstream)? | Local override is justified; document why |
| Is this a security backport? | Patch is justified; link to CVE and upstream fix |

## Exit Conditions

Every override file must have an exit condition comment:

```yaml
# Exit condition: Drop after fdsdk ships X release
# Exit condition: Drop once gnome-build-meta gnome-50 merges MR !NNN
# Exit condition: Permanent — dakota-specific, not upstreamable
```

Without an exit condition, the override becomes permanent maintenance debt with no path to removal.

## Checking Upstream Status

```bash
# Check if a fix is already in GBM gnome-50:
gh api repos/GNOME/gnome-build-meta/commits?sha=gnome-50 | jq '.[].commit.message' | grep -i <fix>

# Check if fdsdk has the fix in their latest tag:
gh api repos/freedesktop-sdk/freedesktop-sdk/releases/latest | jq '.tag_name'
```

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
