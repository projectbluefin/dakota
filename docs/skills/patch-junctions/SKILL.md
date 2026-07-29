---
name: patch-junctions
description: Lifecycle of the patch queues applied to the freedesktop-sdk and gnome-build-meta junctions — adding, rebasing after a ref bump, and dropping a patch. Load when a junction needs a local fix or a bump breaks the queue.
---

# Patching Junction Elements

## Overview

Dakota consumes upstream as two junctions and modifies them with `patch_queue` sources
rather than forks. A patch queue is a directory of `git format-patch` files applied to
the junction's checked-out source, in filename sort order, before any element in that
junction is staged. Because the patch applies to the *source*, a broken patch fails at
staging time — before the element it targets ever builds.

Every patch is maintenance debt. The queue is small on purpose; upstream-first is the
policy, and the correct end state for most patches is deletion.

## When to use

- Upstream has a bug that blocks Dakota and no released ref carries the fix
- A junction ref bump broke patch application
- Upstream merged the fix and the local patch can go

## When not to use

- A newer junction ref already carries the fix → bump instead,
  [update-refs](../update-refs/SKILL.md)
- Replacing which element a junction provides → [bst-overrides](../bst-overrides/SKILL.md)
- General element and source syntax → [buildstream](../buildstream/SKILL.md)

## Authoritative sources

- `elements/freedesktop-sdk.bst` — junction pin, tracked branch pattern, `patch_queue`
- `elements/gnome-build-meta.bst` — junction pin, tracked branch, `patch_queue`,
  and the override that makes this junction reuse Dakota's freedesktop-sdk
- `patches/freedesktop-sdk/`, `patches/gnome-build-meta/` — the queues themselves
- `project.conf` — where the `patch_queue` source plugin comes from, and the
  `git-describe` ref format the junction pins use

## Adding a patch

1. **Rule the alternatives out.** Check whether the tracked branch already carries the
   fix (`just bst source track <junction>.bst` on a scratch branch shows what a bump
   would move to). A bump is always preferable to a patch.
2. **Produce the patch against the pinned ref.** Clone the upstream project, check out
   exactly the ref recorded in the junction element, commit the fix there, and
   `git format-patch` it into the matching `patches/<junction>/` directory.
3. **Name it so it sorts where it must apply.** Application order is the filename sort
   order of the directory, nothing else. Both queues in this tree use a naming style;
   match the one already present rather than introducing a second.
4. **Write the rationale into the patch's own commit message.** The patch file carries
   its `Subject:` and body into the tree — that body is where the reason for the patch
   and the condition that retires it belong. A build-infrastructure patch that will
   never go upstream must say so explicitly; a patch waiting on an upstream merge must
   name what it is waiting for. Nothing validates this, so a patch with a bare subject
   line is indistinguishable from an abandoned one.
5. **Validate the graph, then build.** `just validate` proves the queue still applies and
   the graph resolves; building the element the patch touches proves the change landed
   where it was meant to.

## Rebasing after a junction ref bump

A bump and a patch change should not share a commit — they need different verification
and have to be revertible separately.

When a bump breaks application, decide which of three cases it is before touching the
patch file:

- **Now upstream.** The hunk is already present in the new ref. Delete the patch.
- **Still needed, context moved.** Regenerate it against the new ref by repeating the
  add procedure. Do not hand-edit hunk offsets.
- **Overtaken.** Upstream solved the same problem differently. Delete the patch and
  verify the upstream approach covers Dakota's case; if it does not, that is a new
  patch with a new rationale, not a rebase.

## Failure modes

- **The two junctions are coupled.** `elements/gnome-build-meta.bst` overrides its own
  freedesktop-sdk with Dakota's junction, so gnome-build-meta builds against Dakota's
  patched freedesktop-sdk. A freedesktop-sdk patch can therefore break gnome-build-meta
  elements that never referenced it, and both junctions must stay compatible with the
  version pair upstream expects. Validate the whole graph, not just the element you
  patched.
- **The `[PATCH n/m]` counter in the subject is not maintained.** Counters in this tree
  disagree with each other and with the file count, because patches were dropped without
  renumbering. Filename sort order is the only thing that decides application order.
- **A patch that applies is not a patch that worked.** Context drift can place a hunk
  somewhere harmless and still leave the bug. After any bump, build the affected element
  and check the behavior, not just the exit code of the fetch.
- **Order coupling between patches.** Two patches touching the same file interact
  through the sort order. When adding one to a file that is already patched, read the
  earlier patch first.
- **Kernel changes ride the freedesktop-sdk queue.** There is no separate kernel patch
  directory; a kernel change is a patch to the freedesktop-sdk element that builds it,
  and it must be re-verified against the kernel version in the new ref after a bump.

## Verification

```bash
# Queue applies and both graphs resolve
just validate

# The patched element actually rebuilds
just bst build <element-affected-by-the-patch>

# What is currently in each queue, in application order
ls patches/freedesktop-sdk patches/gnome-build-meta

# The refs the queues are applied on top of
rg -n 'track:|ref:' elements/freedesktop-sdk.bst elements/gnome-build-meta.bst
```

## Related skills

- [update-refs](../update-refs/SKILL.md) — bumping refs, which is what retires patches
- [bst-overrides](../bst-overrides/SKILL.md) — replacing an element instead of patching it
- [buildstream](../buildstream/SKILL.md) — element and source syntax
- [debugging](../debugging/SKILL.md) — when the rebuild after a patch fails
