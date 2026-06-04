# Dep-Update PR Merge Queue

Load when reviewing, retargeting, or merging chore/dep-update PRs
(`auto/track-*`, `renovate/*`) into the `testing` branch.

## When NOT to Use

- Adding a new package → `add-package.md`
- Updating a ref manually → `update-refs.md`
- Junction bumps → `patch-junctions.md`

## Quick Reference

| Task | Command |
|------|---------|
| Retarget PR to testing | `gh pr edit <N> --repo projectbluefin/dakota --base testing` |
| Merge on testing (no protection) | `gh pr merge <N> --repo projectbluefin/dakota --squash` |
| Check dep PRs with CI status | `gh pr list --repo projectbluefin/dakota --state open --json number,title,statusCheckRollup,baseRefName` |

## Why Dep-Update PRs Need Special Handling

Auto-generated dep-update PRs (`auto/track-*` from `track-bst-sources.yml`,
`renovate/*`) always target `main` by default. But new image content merges
to `testing` first. This means:

1. The PR branch is based on `main`, which is behind `testing` in package
   versions but may be ahead in CI/docs commits.
2. Naively merging brings in unrelated CI/docs commits.
3. Some PRs may be **redundant** — `testing` already has the same version.

## Standard Flow

```bash
# 1. Verify the PR has actual new content vs testing
git fetch upstream testing auto/track-<pkg>
git show upstream/testing:elements/bluefin/<pkg>.bst | grep -E "ref:|tag:" | head -3
git show upstream/auto/track-<pkg>:elements/bluefin/<pkg>.bst | grep -E "ref:|tag:" | head -3
# If refs are identical → close the PR, it's redundant.

# 2. Identify the dep-update commit (always the top commit on the PR branch)
git log --oneline upstream/testing..upstream/auto/track-<pkg> | head -1
# e.g.: 8bb62fd chore(deps): update uupd v1.3.0 -> v1.4.0

# 3. Cherry-pick onto a clean testing branch
git fetch upstream testing
git checkout upstream/testing -b rebase/track-<pkg>
git cherry-pick <sha>
# If conflict in the element file: take the newer version from the PR.

# 4. Force-push to the PR branch
git push upstream rebase/track-<pkg>:auto/track-<pkg> --force

# 5. Retarget the PR to testing
gh pr edit <N> --repo projectbluefin/dakota --base testing

# 6. Merge directly (testing has no branch protection)
gh pr merge <N> --repo projectbluefin/dakota --squash \
  --subject "chore(deps): update <pkg> vX -> vY" --body ""
```

## Conflict Resolution

When cherry-picking a dep update onto `testing` that already has an older
version of the same package, there will be a conflict in the element's `ref:`
field. Always take the **newer ref from the PR**:

```bash
# Remove conflict markers, keeping the PR's ref
sed -i '/<<<<<<< HEAD/,/=======/d; />>>>>>> .*/d' elements/bluefin/<pkg>.bst
git add elements/bluefin/<pkg>.bst
GIT_EDITOR=true git cherry-pick --continue
```

## Checking for Redundant PRs

Before spending time rebasing, verify the PR actually changes something:

```bash
# Quick: compare the ref fields
git show upstream/testing:elements/bluefin/<pkg>.bst | grep "ref:" | head -3
git show upstream/auto/track-<pkg>:elements/bluefin/<pkg>.bst | grep "ref:" | head -3

# Thorough: diff only element/files paths
git diff upstream/testing..upstream/auto/track-<pkg> -- elements/ files/ | head -40
```

If the refs are identical → close with:
```bash
gh pr close <N> --repo projectbluefin/dakota \
  --comment "Closing - testing already has this version. No new content to merge."
```

## When E2E Fails on All Dep PRs

`e2e` tests `ghcr.io/projectbluefin/dakota:testing`, not the PR branch.
When the **same** e2e failure appears on every dep-update PR simultaneously,
it is always an infrastructure issue, not a PR issue.

**Diagnosis checklist:**

1. Check if the failure message is "SSH never became ready after 15 minutes" —
   this means the QEMU VM boot failed, caused by a stale or broken `:testing` image.
2. Check `publish.yml` run history for `startup_failure`:
   ```bash
   gh run list --repo projectbluefin/dakota --workflow publish.yml --limit 10 \
     --json databaseId,status,conclusion,createdAt
   ```
   Two or more consecutive `startup_failure` = nightly build is broken,
   `:testing` is stale.
3. Check projectbluefin/testsuite for open issues before filing a new one.

**When infrastructure is confirmed broken:**

- `validate` passing + correct diff is sufficient to merge dep-update PRs.
- Merge with `gh pr merge --squash` directly — `testing` has no protection rules.
- Do NOT wait for e2e to green before merging routine dep bumps.

## ⚠️ `gh pr merge --auto` Does Not Work on `testing`

`testing` has no branch protection rules configured. `--auto` fails with
"Protected branch rules not configured". Always use `--squash` directly:

```bash
# ✅ works
gh pr merge <N> --repo projectbluefin/dakota --squash

# ❌ fails with "Protected branch rules not configured"
gh pr merge <N> --repo projectbluefin/dakota --auto --squash
```

## AGENTS.md Rebase Conflict

When rebasing a branch onto `testing`, `AGENTS.md` reliably conflicts because
`testing` and `main` have diverged. Resolve by keeping the testing version:

```bash
sed -i '/<<<<<<< HEAD/d; />>>>>>> .*/d; /^=======$/d' AGENTS.md
git add AGENTS.md
GIT_EDITOR=true git rebase --continue
```

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`

### Cherry-pick is empty = already in testing (2026-06-04)

If `git cherry-pick <sha>` results in "The previous cherry-pick is now empty",
the content of that commit is **already present** in `testing` by a prior merge.
The PR is redundant — close it rather than forcing an empty commit.

### Multi-PR e2e failure = look at :testing not the PRs (2026-06-04)

When 4+ dep-update PRs all show `e2e / GNOME 50 — smoke: FAILURE` with the
same "SSH never became ready" message, the root cause is always `publish.yml`
not having run recently. Check `gh run list --workflow publish.yml` —
`startup_failure` on the nightly runs means `:testing` is stale and unbootable.
Fix the nightly first; don't debug individual PRs.
