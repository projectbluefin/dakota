---

name: merge-queue
description: Clears stuck dependency-update PRs, rebases chore branches against testing, and handles fork PRs. Covers rebase loops, merge command, e2e retrigger, and cross-repository PR handling. Use when PRs are stuck, conflicting, blocked in queue, or need maintainer-safe rebasing/retriggering.
metadata:
  context7-sources:
    - /websites/github_en_actions
---

# Merge Queue Operations

## When to Use

Use when clearing stuck dependency-update PRs, rebasing chore branches against `testing`, or finishing a batch of bot PR merges.

## Core Process

1. Identify which PRs are actually stale or conflicting.
2. Rebase the minimal set needed.
3. Merge ready PRs in small waves.
4. Re-list and do a cleanup pass, because earlier merges will stale later branches.
5. Handle fork PRs differently from same-repo branches.

## When NOT to Use

- Reviewing normal feature PRs → `pr-review.md`
- Debugging a failing workflow run or cache issue → `ci.md`
- Rebasing a single code branch that is not part of the chore queue

## How to Identify Stuck PRs

Look for these signals:

- chore/dependency PR is open against the wrong base
- merge box shows `CONFLICTING` after other PRs landed in `testing`
- `gh pr merge --auto` fails with `Protected branch rules not configured for this branch`
- e2e is stale and the branch cannot be rerun by pushing
- PR is technically open but has no diff after rebasing onto `testing`

Useful checks:

```bash
gh pr list --repo projectbluefin/dakota --search 'is:open is:pr'
gh pr view <N> --repo projectbluefin/dakota --json baseRefName,headRefName,mergeStateStatus,isCrossRepository
```

## Rebase Conflicting PRs

Content PRs (features, fixes, BST changes) target `testing`. GHA-only dep-update PRs (Renovate workflow pins) also target `testing` and are filtered from builds by `paths-ignore`. Sequential merges advance `testing`, making earlier branches stale.

Use this loop:

1. Merge the ready PRs.
2. Re-list the remaining open PRs.
3. Rebase any PRs still showing `CONFLICTING` or stale checks.
4. Do a final pass after the batch — expect at least one more rebase round.

Standard rebase sequence:

```bash
git fetch upstream <branch> testing
git checkout -B fix-<branch> upstream/<branch>
git rebase upstream/testing
git push upstream HEAD:<branch> --force-with-lease
```

## Merge Chore PRs

`testing` queue cleanup uses direct squash merges rather than `--auto`.

Do **not** use:

```bash
gh pr merge <N> --auto
```

Use direct squash merge instead:

```bash
gh pr merge <N> --repo projectbluefin/dakota --squash
```

## Known `AGENTS.md` Rebase Conflict

When rebasing branches that predate recent `testing` changes, `AGENTS.md` may conflict if both sides modified it.

Resolve by keeping the incoming version and removing conflict markers:

```bash
sed -i '/<<<<<<< HEAD/d; />>>>>>> .*/d; /^=======$/d' AGENTS.md
git add AGENTS.md
GIT_EDITOR=true git rebase --continue
```

## Empty PR Detection

After rebasing onto `testing`, verify the branch still has a diff:

```bash
gh api repos/projectbluefin/dakota/compare/testing...<branch> --jq '{ahead: .ahead_by, behind: .behind_by}'
```

If `ahead` is `0`, `testing` already contains the change. Close the PR with a short note.

## Retriggering e2e

### Same-repo branches

If `gh run rerun` is unavailable because the run is too old, retrigger by pushing an empty commit to the branch:

```bash
git fetch upstream <branch>
git checkout -B retrigger-<N> upstream/<branch>
git commit --allow-empty -m "ci: retrigger e2e"
git push upstream HEAD:<branch>
```

Only do this for branches in `projectbluefin/dakota`.

### Fork PR limitation

Do **not** push to contributor fork branches. You cannot force-push or append empty commits to an external fork from the main repo workflow.

Options:

- `gh run rerun <run-id> --failed` if the run is still recent enough
- comment asking the contributor to push an empty commit

## PR Branch Targets

Content PRs (features, fixes, BST/element changes) target `testing`. **Never `main`** — main only receives squash-merge promotion commits. Check `baseRefName` before rebasing:

```bash
gh pr view <N> --repo projectbluefin/dakota --json baseRefName,isCrossRepository \
  --jq '{base:.baseRefName, cross:.isCrossRepository}'
```

## Cross-Repository (Fork) PRs

When `isCrossRepository: true`, the PR branch lives on the contributor's fork — **not** on `upstream`. `git push upstream HEAD:<branch>` will fail silently or push to the wrong place.

For cross-repo PRs:

```bash
# Check maintainerCanModify first
gh pr view <N> --repo projectbluefin/dakota --json maintainerCanModify,headRepositoryOwner,headRefName

# If maintainerCanModify is true, add fork as remote and push there
git remote add <contributor> git@github.com:<headRepositoryOwner>/dakota.git
git fetch <contributor> <headRefName>
git checkout -B fix-<N> <contributor>/<headRefName>
git rebase upstream/testing
git push <contributor> HEAD:<headRefName> --force-with-lease
```

If `maintainerCanModify: false`, do not push. Request the contributor rebase instead.

## Fleet Parallel Dispatch Pattern

When multiple PRs are all stuck against `testing`, dispatch rebases in parallel, usually in pairs.

Each agent should own one branch and run exactly this sequence:

1. Check `isCrossRepository` — use the fork push path if true (see above)
2. `git fetch upstream <branch>` (or `git fetch <fork> <branch>` for cross-repo)
3. `git checkout -B fix-<branch> upstream/<branch>`
4. `git rebase upstream/testing`
5. `git push upstream HEAD:<branch> --force-with-lease` (or push to fork for cross-repo)

Why pairs: it speeds up queue recovery without turning every branch into a moving target at once. After the first wave lands, run one more cleanup pass for any PRs that became stale during the earlier merges.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just rebase everything at once." | That's how you turn the queue into a moving target. |
| "`--auto` merge will sort it out." | Dakota's queue and ruleset behavior often require explicit handling. |
| "A fork PR is just another branch." | Not if you can't push to it. Treat fork ownership as a first-class constraint. |

## Red Flags

- Rebasing without checking `isCrossRepository`
- Merging a batch without a final stale-branch pass
- Force-pushing to the wrong remote
- Treating empty-after-rebase PRs as if they still need merging

## Verification

- [ ] Stale/conflicting PRs were identified before rebasing
- [ ] Same-repo and fork PRs were handled with the correct push path
- [ ] The queue was processed in waves, not one giant churn pass
- [ ] Empty or already-landed PRs were detected and not merged blindly

## Cross-References

- `ci.md` — reruns, status checks, and workflow behavior
- `pr-review.md` — mergeability and review expectations
