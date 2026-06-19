---

name: bst-overrides
description: Governs when and how to create junction overrides in dakota. Upstream-first principle — local overrides are last resort. Covers patch_queue overrides, exit conditions, and how to evaluate whether an override is justified.
metadata:
  context7-sources:
    - /apache/buildstream
---

# BST Junction Overrides

Load when creating, evaluating, or removing BuildStream junction element overrides in `projectbluefin/dakota`.

## When to Use

Use when you need to decide whether a local override is justified, add a temporary junction override, or remove one after upstream catches up.

## When NOT to Use

- End-to-end patch lifecycle work after deciding an override is required → `patch-junctions.md`
- Routine package updates that stay inside Dakota-owned elements → `update-refs.md`
- Generic BuildStream syntax reference → `buildstream.md`

## Core Process

1. Check whether upstream already fixed the problem.
2. Prefer an upstreamable patch or junction bump.
3. Use a local override only as a last resort.
4. Record the exit condition so the override can die.
5. Revisit overrides whenever junction refs move.

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

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just override it locally for now." | Local overrides are maintenance debt unless they have a clear exit path. |
| "Editing the junction file directly is faster." | Faster to create debt, yes. Use the override mechanisms the repo expects. |
| "We'll remember to drop the override later." | You won't unless the exit condition is written down. |

## Red Flags

- Local override with no upstream issue/PR reference
- No stated exit condition
- Direct edits to junction files as a convenience move
- Override surviving multiple junction bumps without re-evaluation

## Verification

- [ ] Upstream was checked before creating the override
- [ ] The local override mechanism is the narrowest one that works
- [ ] An exit condition is documented
- [ ] The override is discoverable and revisitable at the next junction bump

## Lessons Learned

### Alphabetical patch ordering matters — 0004 is higher priority than 0003 (2026-06-07)

Patch files in `patches/<junction>/` apply in alphabetical (filename) order. Gaps in numbering
are intentional — they leave room to insert patches between existing ones without renaming. Do
not fill gaps just to make the sequence look clean:

```
patches/freedesktop-sdk/
  0001-project-Specify-more-limits-to-the-CAS-configs.patch
  0002-project.conf-Add-GNOME-CAS-servers.patch
  0004-openssh-Use-etc-ssh-as-sysconfdir.patch   ← gap is intentional
  0005-openssh-Include-ssh-_config.d-.conf.patch
```

When inserting a new patch between 0004 and 0005, name it `0004b-...` or `0004c-...` so the
alphabetical order is preserved without renaming `0005+`.

### `gnome-build-meta` currently has only one patch — it's not a typo (2026-06-07)

`patches/gnome-build-meta/disable-lorry-mirrors.patch` is the only GBM patch. Dakota tracks
the most recent GBM ref (latest nightly), which means most fixes are already upstream. The
single-patch state is healthy — it means minimal maintenance debt.

### Verify upstream before adding a patch (2026-06-07)

Before adding a new patch to `patches/<junction>/`:
```bash
# Check if fdsdk already has the fix on their latest tag:
gh api repos/freedesktop-sdk/freedesktop-sdk/releases/latest | jq '.tag_name'

# Check if GBM gnome-50 already has the fix:
git -C ~/.cache/buildstream/sources/git_repo/<gbm-mirror>.git \
  log --oneline origin/gnome-50 | head -20
```

Adding a patch for something already upstream wastes maintenance cycles — junction bump is
cheaper.
