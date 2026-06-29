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

### 10) validate job must run on both `pull_request` AND `merge_group`

If `validate` is the required status check on `main` and the job only runs on
`pull_request`, bot-created promotion PRs hit a circular failure:

1. Bot PR → all `pull_request` runs → `action_required` (org blocks bot runs)
2. `enqueuePullRequest` fails: "Required status check validate is expected"
3. Can never enter the merge queue → stuck forever

**Fix in `build.yml`:**
```yaml
validate:
  if: github.event_name == 'pull_request' || github.event_name == 'merge_group'
```

**Unblocking an already-stuck PR (bootstrap trick):**
The merge queue requires the check to have been posted by integration_id 15368
before `enqueuePullRequest` succeeds. A manually-posted commit status is rejected
("was not set by the expected GitHub app"). The only way to bootstrap is to push
as a non-bot actor — the org bot restriction does not apply to human pushes:

```bash
# Example for any auto-pr-bot branch stuck on first run.
# Historical case was auto/promote-testing-to-main (workflow now deleted);
# the same pattern unblocks any bot-authored PR branch.
git checkout -b unblock upstream/<bot-branch>
git commit --allow-empty -m "ci: trigger validate as non-bot actor"
git push upstream unblock:<bot-branch>
# validate fires on pull_request:synchronize as human → posts check run
# enqueuePullRequest now succeeds
```

Remove the empty commit branch after the PR merges.

### 11) Renovate automerge fails on workflow-file bumps — use Mergeraptor token

When a Renovate PR updates an action SHA inside `.github/workflows/`, GitHub
refuses to merge it without `workflows` permission:

```
GraphQL: refusing to allow a GitHub App to create or update workflow
`.github/workflows/build.yml` without `workflows` permission
```

The automerge job silently swallows the error (warning: "PR merge skipped") and
the PR stays open with `pr/needs-review`.

**`workflows: write` is NOT the fix.** It is not a valid `GITHUB_TOKEN` scope —
actionlint rejects it with `unknown permission scope "workflows"`. This is a hard
rule in AGENTS.md. Do not add it. Do not suppress the actionlint error.

**Correct fix:** The reusable `renovate-automerge.yml` in `projectbluefin/actions`
uses the Mergeraptor GitHub App token internally, which has the `workflows` GitHub
App permission. If workflow-file bumps are still not auto-merging, check that:
1. `MERGERAPTOR_APP_ID` and `MERGERAPTOR_PRIVATE_KEY` secrets are set on the repo
2. The Mergeraptor app has `workflows` permission granted in org settings

### 11b) Branch-sync workflows that push workflow files need the Mergeraptor token

`sync-next-from-main.yml` merges `main` into `next`. When that merge includes
changes to `.github/workflows/` files, the push fails:

```
remote: refusing to allow a GitHub App to create or update workflow
`.github/workflows/build.yml` without `workflows` permission
```

`GITHUB_TOKEN` with `contents: write` cannot push workflow file changes —
GitHub requires a token with `workflows` scope, and `workflows: write` is not
a valid `GITHUB_TOKEN` permission (actionlint error: `unknown permission scope
"workflows"`).

**Fix:** Use the Mergeraptor GitHub App token (which has `workflows` permission
as an installed GitHub App) for checkout and push:

```yaml
permissions:
  contents: read  # NOT contents: write — app token handles the push

jobs:
  sync-next:
    steps:
      - name: Get mergeraptor token
        id: app-token
        uses: actions/create-github-app-token@<sha> # v3
        with:
          app-id: ${{ secrets.MERGERAPTOR_APP_ID }}
          private-key: ${{ secrets.MERGERAPTOR_PRIVATE_KEY }}

      - name: Checkout next
        uses: actions/checkout@<sha> # v6
        with:
          ref: next
          fetch-depth: 0
          token: ${{ steps.app-token.outputs.token }}
```

This pattern is also used in `track-bst-sources.yml` and `track-next-junctions.yml`.

### 12) `sync-main-to-testing` resets testing to main — CI-only PRs to testing get wiped

The sync workflow runs on every push to `main`. It merges main into testing.
If testing has commits that are not yet on main (e.g. a feature PR merged to testing
before its content promoted), those commits survive the sync (merge wins).

**But:** if testing was at the same SHA as main when the feature PR landed, and then
a *different* push triggered sync before the feature PR's content was promoted, the
sync fast-forwards testing to the new main HEAD, which may not include the feature commits
if they diverged from a stale base.

**Observed:** PR #1045 (aarch64 workflow) merged to testing at 00:16 UTC.
`sync-main-to-testing` ran at 02:38 UTC for an unrelated main push. Testing was reset
to main's HEAD, erasing the aarch64 commit. Had to re-land as PR #1051.

**Rule:** For CI-only changes that must survive to the next promotion, target `testing`
and ensure promotion fires before the next unrelated push to `main`. Or target `main`
directly (CI-only PRs can merge without review) to skip the sync race entirely.

### 13) execute-release fires on CI-only main push — release-notes step fails

`execute-release.yml` triggers on every `push: branches: main`. When the push is
CI-only (no `publish.yml` image build ran for that commit), the `release-notes /
Create stable image release` step fails:

```
::error::Could not find a successful publish.yml run on main
```

`check-trigger` does not detect CI-only pushes and bail early. This is a known bug
(tracked in issue 1061). It does not affect image publishing (`execute / execute`
succeeds) — only the GitHub Release creation step fails.

**Workaround:** Ignore the `release-notes` failure when the triggering push was
CI-only. The image is still published correctly.

### 14) `BST_SHOW_OUT=$(cmd)` with bash -e exits on bst show failure (2026-06-23)

GHA `run:` steps use `shell: /usr/bin/bash -e {0}` by default. With errexit active,
`VAR=$(cmd 2>&1)` exits immediately if `cmd` fails — the `rc=$?` line never executes.

**Symptom:** "Count elements for progress tracking" exits with 255 (or whatever bst
show returned) instead of emitting a `::warning::` and continuing.

```
##[error]Process completed with exit code 255.
```

**Fix:** Wrap the assignment with `set +e` / `set -e`:

```bash
set +e
BST_SHOW_OUT=$(just bst show --deps all --format '%{name}' oci/bluefin.bst 2>&1)
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  ...
```

This pattern is now used in `build.yml` (fixed in
commit `1f89a42`). Apply the same pattern to any future step that needs to capture
both the output and exit code of a command that may fail.

### 15) `${{ inputs.X }}` in job `if:` causes startup_failure on workflow_run triggers

**Symptom:** `startup_failure` with zero jobs and zero log output on a workflow
triggered by `workflow_run`. The same workflow works fine when triggered by
`workflow_dispatch`.

**Root cause:** `${{ }}` expression syntax in a job `if:` condition that references
the `inputs` context. When triggered by `workflow_run`, the `inputs` context is absent.
The `${{ }}` wrapper evaluates it and errors at startup before any jobs are created.

```yaml
# BROKEN — startup_failure when triggered by workflow_run (inputs absent)
if: ${{ inputs.dry_run != true && github.event_name == 'workflow_run' }}

# CORRECT — bare if: handles absent inputs context safely (null != true = true)
if: inputs.dry_run != true && github.event_name == 'workflow_run'
```

**Scope:** Affects any workflow that:
1. Can be triggered by both `workflow_run` and `workflow_dispatch`
2. Has job `if:` conditions using `${{ inputs.X }}`

**Diagnosis:** Search the workflow file for all `if:` conditions containing
`${{ }}` that reference `inputs`. All of them need the wrapper removed.

### 15b) Undeclared input passed to reusable workflow — startup_failure

**Symptom:** `startup_failure` with zero jobs, identical to pattern 15. Actionlint is clean.
YAML parses correctly. The fix for pattern 15 (removing `${{ }}`) doesn't resolve it.

**Root cause:** The caller workflow passes an input via `with:` that the reusable workflow
does NOT declare in its `on.workflow_call.inputs:`. GitHub validates the workflow graph
at dispatch time and fails before any jobs start.

```yaml
# BROKEN — build_run_id not declared in reusable-release.yml
uses: org/actions/.github/workflows/reusable-release.yml@v1
with:
  build_run_id: ${{ github.event.workflow_run.id }}   # undeclared input
  build_workflow: publish.yml

# CORRECT — only pass declared inputs
uses: org/actions/.github/workflows/reusable-release.yml@v1
with:
  build_workflow: publish.yml
```

**Fix:** Remove the undeclared input from the caller's `with:` block. If the feature is
needed, add the input declaration to the reusable workflow's `on.workflow_call.inputs:` first.

**Why pattern 15 fixes don't help:** Removing `${{ }}` from `if:` conditions is correct
but does not prevent graph-validation failure on undeclared inputs.

**Actionlint does not catch this.** YAML is valid, actionlint passes, error is runtime-only.

**Verification:** Dispatch the fixed workflow and confirm jobs appear (not `startup_failure` with 0 jobs).

### 16) Automerge workflow must follow the PR validation workflow, not the build workflow

If a reusable automerge workflow matches PRs by `head_sha`, it must listen to the workflow that runs on the PR commit itself. `build.yml` on Dakota only runs on schedule/dispatch/merge queue, so its `workflow_run.head_sha` is the trunk SHA, not the PR head SHA. That makes the reusable automerge step log "No open ... PR found for SHA ..." and silently skip.

**Fix:** Trigger automerge from `Validate` (the PR workflow) instead of `Build Bluefin dakota`. Then `github.event.workflow_run.head_sha` is the PR commit SHA the reusable workflow expects.

**Symptom:** open dependency PRs stay mergeable and green but never get `autoMergeRequest` set.

## Red Flags

- `permissions: {}` on a reusable workflow caller
- `startup_failure` with no jobs inspected
- podman `statfs ... no such file or directory`
- trying to use `continue-on-error` to tame a reusable-workflow call job
- relying on `GITHUB_TOKEN` for bot PRs that need PR checks to fire
- `persist-credentials: false` in a workflow that runs in a repo with submodules
- a sync workflow living only on the non-default branch (it will never fire)
- `base_branch` not passed to `reusable-renovate-automerge` or passed with wrong value
- bot actors excluded from `pr-autoupdate` while their PRs go behind
- `validate` job condition is `pull_request` only — blocked in merge queue for bot PRs
- `renovate-automerge` missing Mergeraptor token — workflow-file bumps silently strand
- landing a CI feature on `testing` and assuming it survives the next sync-main-to-testing
- `pr-triage` gate only allowing `renovate/*` to target `testing`, blocking feature PRs
- rapid-fire PR merges cancelling each other's pending builds (manual dispatch needed)
- `if: ${{ inputs.X }}` in a job condition on a workflow that can be triggered by `workflow_run`
- `with:` block in a reusable workflow call passing inputs not declared in the target workflow
- `startup_failure` that persists after fixing all `${{ }}` in `if:` conditions (check undeclared inputs)
- automerge hooked to a non-PR workflow, so `head_sha` never matches the PR branch

## Verification

- [ ] You checked whether the run had `jobs: []`
- [ ] You inspected top-level caller permissions before editing nested jobs
- [ ] Any podman bind-mounted cache dir is created explicitly
- [ ] Required checks are aligned with `pull_request` visibility
- [ ] The fix reduces CI ambiguity instead of adding more magic
- [ ] `persist-credentials: false` not added to repos with incomplete `.gitmodules`
- [ ] Branch-sync workflow lives on the default branch, not on the target branch
- [ ] `reusable-renovate-automerge` calls omit `base_branch` (default is `testing`) or pass the correct branch
- [ ] `pr-autoupdate` has no actor exclusions that would strand bot PRs
- [ ] `validate` job runs on both `pull_request` and `merge_group` (not just `pull_request`)
- [ ] `renovate-automerge.yml` does NOT have `workflows: write` (invalid scope — actionlint rejects it; use Mergeraptor app token instead)
- [ ] CI-only changes that must survive sync are either landed on main directly or promoted before the next unrelated main push
- [ ] All job `if:` conditions in dual-trigger workflows (`workflow_run` + `workflow_dispatch`) use bare expressions, not `${{ }}` wrappers
