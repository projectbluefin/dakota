---

name: patch-junctions
description: Lifecycle for patches applied to upstream junctions (freedesktop-sdk, gnome-build-meta). Covers adding patches, required Upstream-Status headers, rebasing after junction bumps, and dropping upstreamed patches.
metadata:
  context7-sources:
    - /apache/buildstream
---

# Patching Junction Elements

Load when modifying upstream freedesktop-sdk or gnome-build-meta elements in dakota, or when fixing bugs in junction dependencies.

## When to Use

Use when an upstream junction dependency needs a local patch in Dakota or when maintaining/rebasing an existing junction patch queue.

## When NOT to Use

- Understanding when to override vs. not → `bst-overrides.md`
- Bumping a junction ref without patch changes → `update-refs.md`

## Core Process

1. Confirm a patch is really needed and not just a junction bump.
2. Add the patch with the required metadata/header.
3. Track the upstream status explicitly.
4. Rebase or drop the patch as upstream moves.
5. Keep the queue minimal and ordered.

## Overview

Dakota applies patches to upstream junctions via `patch_queue` source blocks in the junction `.bst` files. Patches apply in **alphabetical filename order**.

```text
patches/gnome-build-meta/   ← patches for gnome-build-meta junction
patches/freedesktop-sdk/    ← patches for freedesktop-sdk junction
patches/linux/              ← kernel patches (apply against kernel source)
```

## Patch Lifecycle

```text
Add patch → Upstream-Status header → track upstream PR →
upstream merges → junction bump includes fix → drop patch
```

Every patch is maintenance debt. Drop as soon as upstream ships the fix.

## Required Headers

Every patch file must include an `Upstream-Status:` header:

| Value | Meaning |
|-------|---------|
| `Submitted` | PR/MR submitted upstream; include URL |
| `Accepted` | Merged upstream; will be dropped on next junction bump |
| `Pending` | Not yet submitted; should be submitted soon |
| `Not-applicable` | Dakota-specific change; will never be upstreamed |

```patch
From: Author <email>
Date: ...
Subject: [PATCH] Fix something

Upstream-Status: Submitted https://github.com/org/repo/pull/NNN
Exit condition: Drop after gnome-build-meta gnome-50 merges MR !NNN
```

## Adding a Patch

1. **Get the upstream source into a working directory:**
   ```bash
   # Use the BST source cache (no network needed)
   git -C ~/.cache/buildstream/sources/git_repo/<junction>.git \
     worktree add /tmp/<junction>-work <CURRENT_REF>
   ```

2. **Make and commit the change:**
   ```bash
   cd /tmp/<junction>-work
   # make your edit
   git add -A
   git commit -m "Fix: <description>"
   git format-patch -1 HEAD -o <repo-root>/patches/<junction>/
   ```

3. **Name the patch file** — filenames are applied alphabetically:
   ```
   0001-fix-something.patch
   0002-another-fix.patch
   ```

4. **Add required headers** to the patch file (see above)

5. **Validate:**
   ```bash
   just bst show oci/bluefin.bst
   just bst build <affected-element>
   ```

## Junction Bump + Patch Rebase

When bumping a junction ref, every patch in the relevant `patches/` directory must still apply cleanly.

**Check first — the fix may already be upstream:**
```bash
grep -r '<thing-you-patched>' /tmp/<junction>-work/
# If found in upstream: just drop the patch, don't rebase
```

**Rebase a patch:**
```bash
# Check out new upstream ref
git -C ~/.cache/buildstream/sources/git_repo/<junction>.git \
  worktree add /tmp/<junction>-new <NEW_REF>

# Try applying with -C1 (tolerates offset drift)
cd /tmp/<junction>-new
git apply --ignore-whitespace -C1 <repo-root>/patches/<junction>/<patch>.patch

# If -C1 fails, apply manually then extract:
# Make the equivalent change manually
git add -A
git diff --cached > /tmp/<patch>-rebased.patch
git checkout -- .
git apply /tmp/<patch>-rebased.patch && echo "VERIFY OK"

# Copy back
cp /tmp/<patch>-rebased.patch <repo-root>/patches/<junction>/<patch>.patch
```

**After rebasing all patches:**
```bash
just bst show oci/bluefin.bst   # must exit clean
just bst build oci/bluefin.bst  # verify full build
```

## Dropping a Patch

When the upstream junction ref includes the fix:
1. `git rm patches/<junction>/<patch>.patch`
2. `just bst show oci/bluefin.bst` — verify clean
3. Note in commit message: "Drop patch — fixed in upstream <ref>"

## Common Issues

| Issue | Fix |
|-------|-----|
| Patch applies but causes test failure | Check patch context with `-C2` or `-C3` |
| Hunk offset drift after junction bump | Rebase with `-C1`, then verify with `just bst build` |
| Patch file not found / wrong name | Filenames are alphabetical order; check numbering |
| `patch_queue` source not in junction `.bst` | Must be declared as a source in the junction element |
| Multiple patches conflict | Check filename ordering — earlier patches may change context for later ones |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll add the patch now and upstream it later." | That is how patch queues become permanent. |
| "One more local patch is cheap." | Every local junction patch compounds rebase debt. |
| "Filename order probably won't matter here." | The queue is order-sensitive. Treat it that way. |

## Red Flags

- Patch with no upstream tracking reference
- Missing or weak `Upstream-Status` metadata
- Queue growth without drop/rebase discipline
- Local patch solving something a junction bump already fixed

## Verification

- [ ] Patch was justified over a simple junction bump
- [ ] Upstream tracking/status is explicit
- [ ] Queue ordering and rebase implications were considered
- [ ] There is a clear path to drop the patch later

## Lessons Learned

### Junction patch rebase when upstream bumps a junction ref

When a PR bumps a junction ref, patches in `patches/<junction>/` may become stale due to hunk offset drift.

**Check first — the module may already be upstreamed:**
```bash
grep -n 'MODULE_NAME_HERE' /tmp/<junction>-work/files/linux/fdsdk-config.sh
# If already present: git rm patches/<junction>/<patch>.patch — don't rebase a no-op
```

**Rebase with `-C1` to tolerate offset drift** — this handles the majority of cases automatically.

BST source cache is available locally: `~/.cache/buildstream/sources/git_repo/`. No network needed for rebase work.

> Add further entries here when you discover a new pattern.
> Format: `### <pattern name> (YYYY-MM-DD)`
