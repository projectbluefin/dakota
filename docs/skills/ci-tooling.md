---
name: ci-tooling
description: GitHub Actions failure patterns for Dakota: reusable workflow permissions, startup_failure, actions/cache bind-mount traps, token suppression, and ruleset interactions. Use when workflows do not start, show jobs: [], or fail before the real work begins.
metadata:
  context7-sources:
    - /websites/github_en_actions
---

# CI Tooling Failures

## Overview

Most Dakota CI pain is not "the build failed". It is **GitHub Actions plumbing**:
reusable workflow calls, token scopes, cache directories, rulesets, and trigger semantics.
This skill is for failures that happen **before** the image logic.

## When to Use

Use when you see:
- `startup_failure`
- `jobs: []`
- reusable workflow call jobs that never start
- `actions/cache` + podman bind-mount weirdness
- PRs created by automation that do not trigger checks
- merge queue or ruleset behavior that makes a valid workflow look broken

## When NOT to Use

- Need to know which workflow should have run → `workflow-map.md`
- boot-check or smoke failures after the workflow already started → `e2e-ci.md`
- stable promotion flow, release gates, or action-required promotion PRs → `release-promotion.md`

## Core Process

1. **Check whether the workflow created jobs at all.**
   - `gh run view <id> --json jobs,conclusion`
   - If `jobs: []`, treat it as workflow syntax / permission / accessibility first.
2. **For reusable workflow callers, inspect top-level `permissions:` first.**
   - Caller permissions set the token ceiling.
   - Nested workflows can only keep or reduce permissions, never elevate them.
3. **Check job type before applying a fix.**
   - `uses:` jobs behave differently from normal `runs-on:` jobs.
4. **For podman bind mounts, ensure host cache dirs exist before the step.**
5. **Only after the plumbing is sound, debug the actual build/test logic.**

## High-Value Failure Patterns

### 1) Reusable workflow token starvation

If a thin caller uses `jobs.<id>.uses`, the caller's top-level `permissions:`
cap the token for the entire reusable workflow chain.

**Bad pattern:**
```yaml
permissions: {}

jobs:
  gate:
    permissions:
      contents: read
      pull-requests: write
    uses: org/repo/.github/workflows/reusable.yml@v1
```

**Good pattern:**
```yaml
permissions:
  contents: read
  pull-requests: write
  actions: read
  packages: read
  issues: write

jobs:
  gate:
    uses: org/repo/.github/workflows/reusable.yml@v1
```

Use this first when a reusable caller shows `startup_failure` and `jobs: []`.

### 2) `actions/cache` restores content, not directories

On a cold miss, `actions/cache` does not create the target path.
If podman bind-mounts a missing host path, the container fails to start.

```bash
mkdir -p "${HOME}/.cache/buildstream" "${HOME}/.cache/pip"
podman run --rm \
  -v "${HOME}/.cache/buildstream:/root/.cache/buildstream:rw" \
  -v "${HOME}/.cache/pip:/root/.cache/pip:rw" ...
```

### 3) Bot-created PRs with `GITHUB_TOKEN` suppress `pull_request`

If a workflow creates a PR using `GITHUB_TOKEN`, GitHub suppresses recursive
`pull_request` events. Use a GitHub App token for bot PR creation when checks
must fire on the new PR.

### 4) Required checks must exist on `pull_request`

A check that only runs on `merge_group` cannot satisfy a PR ruleset. If the
merge queue button is blocked, verify the required checks are PR-visible.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I set job-level permissions, so the reusable workflow can write." | Not if the caller's top-level permissions deny it. |
| "actions/cache handles the path for me." | It handles archives, not directory creation. |
| "The workflow is broken because it has no logs." | `jobs: []` usually means the workflow never got past validation. |
| "I'll fix it by adding more permissions everywhere." | Wrong. Add the minimal top-level superset the reusable chain actually needs. |

### 5) `persist-credentials: false` breaks submodule cleanup

`actions/checkout` with `persist-credentials: false` runs `git submodule foreach`
during credential cleanup. If any submodule path in `.gitmodules` has no URL, it fails:

```
fatal: No url found for submodule path '.workflow-scripts' in .gitmodules
```

**Fix:** Remove `persist-credentials: false`. `GITHUB_TOKEN` is short-lived and
scoped — the risk is acceptable. Do not add this flag to workflows that operate in
repos with submodule path entries lacking URLs.

### 6) Push-triggered workflows only fire from the default branch

A workflow with `on: push: branches: [main]` that lives **only on the `next` branch**
will **never fire**. GitHub only reads workflow files from the default branch when
evaluating push triggers.

**Fix:** The sync workflow (`sync-next-from-main.yml`) must live on `main`. It then
fires on every `push: main` and merges main into `next`. A copy also lands on `next`
via the sync itself (harmless — the `next` copy is never triggered).

### 7) Branch protection blocking workflow direct push

If the target branch (e.g. `next`) has "Require a pull request before merging"
enabled and `github-actions[bot]` is not in the bypass list, any direct push from a
workflow fails:

```
remote: error: GH006: Protected branch update failed
remote: - Changes must be made through a pull request.
```

**Fix for dev/rolling branches:** Remove the PR requirement entirely — `next` is a
dev stream, not production. Run:
```bash
gh api -X DELETE repos/<org>/<repo>/branches/next/protection/required_pull_request_reviews
```

**Fix for prod branches:** Add `github-actions` (app ID 15368) to
`bypass_pull_request_allowances` in the branch protection settings.

### 8) Renovate/mergeraptor automerge — `base_branch` must match PR target

The `projectbluefin/actions` reusable `renovate-automerge` workflow uses `base_branch`
to filter which PRs to automerge. Dakota dep PRs target `testing` (testing-first model),
which matches the reusable workflow default. Do **not** override with `base_branch: main`:

```yaml
# Correct — no base_branch override needed, default is "testing"
jobs:
  automerge:
    uses: projectbluefin/actions/.github/workflows/reusable-renovate-automerge.yml@<sha> # v1
    with:
      head_sha: ${{ github.event.workflow_run.head_sha }}
      # base_branch omitted — defaults to "testing", which is correct
```

### 9) Excluding bot actors from `pr-autoupdate` strands their PRs

If `pr-autoupdate.yml` explicitly excludes a bot actor (e.g. `app/mergeraptor`) from
branch-update logic, that bot's PRs accumulate `behind` status and never merge.
Bots create PRs but do not self-update branches when the base advances.

**Fix:** Remove all actor exclusions from `pr-autoupdate`. Any PR targeting `main`
that has gone behind should be updated, regardless of who opened it.

### 10) Branch syncs should restore the target branch's own `.github/workflows/`

When a branch-sync workflow merges `main` into another branch, the merge can pull in
changes under `.github/workflows/**`. Pushing those workflow file changes can fail or
force you into unnecessary credential escalation.

**Fix:** After `git merge origin/main -X theirs --no-edit`, restore the target
branch's pre-merge `.github/workflows/` tree with
`git checkout HEAD@{1} -- .github/workflows/`, then stage
`.github/workflows/` before amending the merge commit. This preserves the target
branch's workflow files while still syncing other `.github/` content from `main`.


## Red Flags

- `permissions: {}` on a reusable workflow caller
- `startup_failure` with no jobs inspected
- podman `statfs ... no such file or directory`
- trying to use `continue-on-error` to tame a reusable-workflow call job
- relying on `GITHUB_TOKEN` for bot PRs that need PR checks to fire
- `persist-credentials: false` in a workflow that runs in a repo with submodules
- a sync workflow living only on the non-default branch (it will never fire)
- a branch-sync workflow that would push `.github/workflows/**` instead of restoring the target branch's own `.github/workflows/`
- `base_branch` not passed to `reusable-renovate-automerge` or passed with wrong value
- bot actors excluded from `pr-autoupdate` while their PRs go behind
- pr-triage gate only allowing `renovate/*` to target `testing`, blocking feature PRs
- rapid-fire PR merges cancelling each other's pending builds (manual dispatch needed)

## Verification

- [ ] You checked whether the run had `jobs: []`
- [ ] You inspected top-level caller permissions before editing nested jobs
- [ ] Any podman bind-mounted cache dir is created explicitly
- [ ] Required checks are aligned with `pull_request` visibility
- [ ] The fix reduces CI ambiguity instead of adding more magic
- [ ] `persist-credentials: false` not added to repos with incomplete `.gitmodules`
- [ ] Branch-sync workflow lives on the default branch, not on the target branch
- [ ] Branch-sync workflows that would carry `.github/workflows/**` restore the target branch's own `.github/workflows/` before push
- [ ] `reusable-renovate-automerge` calls omit `base_branch` (default is `testing`) or pass the correct branch
- [ ] `pr-autoupdate` has no actor exclusions that would strand bot PRs
- [ ] pr-triage gate allows all PRs targeting `testing`, not just `renovate/*`
- [ ] After rapid-fire merges to main/testing, check for cancelled builds and re-trigger with `gh workflow run build.yml --ref <branch>`
