# Merge Queue Operations

## When to Load

Load when clearing stuck dependency-update PRs, rebasing chore branches against `testing`, or finishing a batch of bot PR merges.

## When NOT to Use

- Reviewing normal feature PRs → `pr-review.md`
- Debugging a failing workflow run or cache issue → `ci.md`
- Rebasing a single code branch that is not part of the chore queue

## How to Identify Stuck PRs

Look for these signals:

- chore/dependency PR is open against `main` instead of `testing`
- merge box shows `CONFLICTING` after other chore PRs landed in `testing`
- `gh pr merge --auto` fails with `Protected branch rules not configured for this branch`
- e2e is stale and the branch cannot be rerun by pushing
- PR is technically open but has no diff after rebasing onto `testing`

Useful checks:

```bash
gh pr list --repo projectbluefin/dakota --search 'is:open is:pr'
gh pr view <N> --repo projectbluefin/dakota --json baseRefName,headRefName,mergeStateStatus,isCrossRepository
```

## Retarget Chore PRs to `testing`

Bot PRs from mergeraptor and renovate are created against `main` by default. Dependency-update chores must land in `testing` first.

1. Retarget the PR:

```bash
gh pr edit <N> --base testing --repo projectbluefin/dakota
```

2. Fetch the branch and rebase it onto `upstream/testing`:

```bash
git fetch upstream <branch> testing
git checkout -B fix-<branch> upstream/<branch>
git rebase upstream/testing
git push upstream HEAD:<branch> --force-with-lease
```

3. Re-check mergeability:

```bash
gh pr view <N> --repo projectbluefin/dakota --json mergeStateStatus
```

## Rebase Conflicting PRs

Sequential merges into `testing` advance the target branch every time. A branch that was clean before PR #1 can become stale after PRs #2 through #6 land.

Use this loop:

1. Merge the ready PRs.
2. Re-list the remaining open chore PRs.
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

`testing` does not have auto-merge configured in branch protection.

Do **not** use:

```bash
gh pr merge <N> --auto
```

Use direct squash merge instead:

```bash
gh pr merge <N> --repo projectbluefin/dakota --squash
```

## Known `AGENTS.md` Rebase Conflict

When rebasing from `main` onto `testing`, `AGENTS.md` often conflicts because `testing` already contains the text being replayed.

Resolve by keeping the `testing` version (`HEAD`) and removing conflict markers:

```bash
sed -i '/<<<<<<< HEAD/d; />>>>>>> .*/d; /^=======$/d' AGENTS.md
git add AGENTS.md
GIT_EDITOR=true git rebase --continue
```

If the only conflict is duplicated text already present on `testing`, do not try to manually merge both sides.

## Empty PR Detection

After rebasing onto `testing`, verify the branch still has a diff:

```bash
gh api repos/projectbluefin/dakota/compare/testing...<branch> --jq '{ahead: .ahead_by, behind: .behind_by}'
```

If `ahead` is `0`, the target branch already contains the change. Close the PR with a short note explaining that rebasing showed no remaining diff.

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

## Feature PRs vs Chore PRs — Different Targets

- **Chore / dep-update PRs** → target `testing`. Rebase onto `upstream/testing`.
- **Feature / fix PRs** → target `main`. Rebase onto `upstream/main`.

Retargeting a feature PR to `testing` is wrong. Check `baseRefName` before rebasing:

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
git rebase upstream/main      # or upstream/testing for chores
git push <contributor> HEAD:<headRefName> --force-with-lease
```

If `maintainerCanModify: false`, do not push. Request the contributor rebase instead.

## Fleet Parallel Dispatch Pattern

When multiple chore PRs are all stuck against `testing`, dispatch rebases in parallel, usually in pairs.

Each agent should own one branch and run exactly this sequence:

1. Check `isCrossRepository` — use the fork push path if true (see above)
2. `git fetch upstream <branch>` (or `git fetch <fork> <branch>` for cross-repo)
3. `git checkout -B fix-<branch> upstream/<branch>`
4. `git rebase upstream/testing`
5. `git push upstream HEAD:<branch> --force-with-lease` (or push to fork for cross-repo)

Why pairs: it speeds up queue recovery without turning every branch into a moving target at once. After the first wave lands, run one more cleanup pass for any PRs that became stale during the earlier merges.

## Cross-References

- `ci.md` — reruns, status checks, and workflow behavior
- `pr-review.md` — mergeability and review expectations
