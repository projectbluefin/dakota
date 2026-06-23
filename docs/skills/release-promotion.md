---
name: release-promotion
description: Dakota publish and promotion flow from testing to main to stable, including promotion PRs, merge queue wiring, release gate behavior, and manual recovery. Use when working on promote-testing-to-main.yml, action_required on promotion PRs, merge queue setup, branch protection, or stable-cut logic.
metadata:
  context7-sources:
    - /websites/github_en_actions
    - /bootc-dev/bootc
---

# Release Promotion

## Overview

Promotion from `testing` to `main` is **fully automated** — no human approval required at any stage.

```text
testing → promotion PR (cosign gate) → merge queue → main → :latest / :stable
```

Do not conflate "publish is healthy" with "stable promotion is healthy".

## When to Use

Use when the task mentions:
- `promote-testing-to-main.yml`
- `pr-release-gate.yml`
- `execute-release.yml`
- promotion PRs from `auto/promote-testing-to-main`
- `action_required` on promotion PR checks
- merge queue, `use_merge_queue`, `enqueuePullRequest`
- branch protection or ruleset on `main`
- stable release, `:latest`, `:stable`, or promotion PR flow

## When NOT to Use

- Need to know which workflow owns a stage → `workflow-map.md`
- Workflow never starts because of caller permissions or cache plumbing → `ci-tooling.md`
- Boot-check or smoke mechanics → `e2e-ci.md`

## Core Process

1. **Run the CI pre-flight first.** Verify `OK: field is clear` before any action.
   See Hard Rule #9 in `.github/copilot-instructions.md`. No exceptions.
2. **Identify the stage.**
   - publish to `:testing`
   - open/update promotion PR
   - gate the promotion PR (cosign verify)
   - execute stable release after merge
3. **`action_required` on promotion PR checks is expected and normal.**
   The org blocks `github-actions[bot]`-triggered PR workflow runs. This means
   `validate` and all other `pull_request` checks show `action_required` on every
   promotion PR. This is NOT a failure — the merge queue bypasses it.
4. **The merge queue is the only correct auto-merge path for dakota.**
   `gh pr merge --auto` (`enablePullRequestAutoMerge`) is blocked by the merge queue
   ruleset. Only `enqueuePullRequest` (triggered by `use_merge_queue: true`) works.
5. **Do not add e2e back into the promotion PR path.**
   Dakota intentionally gates stable at the later human-approved release stage.
6. **Automatic promotion cadence is Tuesday 04:00 UTC.**
   That schedule re-evaluates the promotion PR for the weekly stable cut.
7. **For manual recovery, re-run the failed publish/promote workflow that owns the stage.**

## Promotion Map

```text
push to testing (BST-affecting paths)
  → build.yml (build job)
  → publish.yml (workflow_run)
      → :testing tag published to GHCR
  → promote-testing-to-main.yml
      → auto/promote-testing-to-main PR
           → pr-release-gate.yml (cosign verify :testing)
           → enqueuePullRequest → merge queue
               → merge_group event → validate check (bypasses action_required)
               → merge to main
                   → execute-release.yml (commit message gate)
                       → :latest / :stable + GitHub Release
```

## Branch Protection and Ruleset State

Ruleset: `main-merge-queue-no-review` (id: 18008292)

| Rule | Value |
|---|---|
| Required reviews | 0 (fully automated) |
| Required status checks | `validate` (strict) |
| Merge queue | SQUASH, ALLGREEN, max_entries_to_build=2, timeout=120 min |
| Bypass actors | OrganizationAdmin (always), Renovate (PR), mergeraptor (PR) |
| Non-fast-forward | enforced |
| Deletion | blocked |

Classic branch protection on `main`: `required_approving_review_count: 0`.

**Never re-add a required review count to classic protection or the ruleset.** It blocks every automated promotion PR permanently — the GHA bot cannot approve its own PRs.

## Workflow Configuration

`promote-testing-to-main.yml` must always have `use_merge_queue: true`:

```yaml
jobs:
  promote:
    uses: projectbluefin/actions/.github/workflows/reusable-promote-squash.yml@v1
    with:
      variants: '[{"image":"dakota"},{"image":"dakota-nvidia"}]'
      cosign_identity_regexp: >-
        ^https://github\.com/projectbluefin/(dakota|actions)/\.github/workflows/
      run_e2e: false
      use_merge_queue: true
```

Do not make `use_merge_queue` conditional on event type. It must always be `true`.

## Hard Rules

- `promote-testing-to-main.yml` is a thin caller. Treat caller-level `permissions:` as critical.
- `pr-release-gate.yml` must not starve the reusable gate token.
- Promotion PRs do **not** run the full e2e quality gate; that belongs at the weekly stable gate.
- `use_merge_queue: true` — unconditional, always. Not conditional on `github.event_name`.
- The merge queue ruleset (`merge_queue` rule type) must exist on `main`. Without it, `enqueuePullRequest` fails silently.
- `required_approving_review_count` must be 0 in both ruleset and classic branch protection.
- Weekly automatic stable evaluation runs Tuesday at `0 4 * * 2`.
- Keep `run_e2e: false` in dakota's promotion caller.

## Manual Recovery Shortcuts

```bash
# open promotion PR status
gh pr list --repo projectbluefin/dakota \
  --search 'head:auto/promote-testing-to-main state:open'

# recent gate runs
gh run list --repo projectbluefin/dakota --workflow 'PR Release Gate' --limit 10

# recent promote runs
gh run list --repo projectbluefin/dakota --workflow 'Promote testing to main' --limit 10

# verify ruleset is correct
gh api repos/projectbluefin/dakota/rulesets | jq '[.[] | {id, name}]'
gh api repos/projectbluefin/dakota/rulesets/18008292 | jq '[.rules[].type]'

# verify classic branch protection has 0 reviews
gh api repos/projectbluefin/dakota/branches/main/protection \
  | jq '.required_pull_request_reviews.required_approving_review_count'
```

## Why `use_merge_queue: true` is required (not optional)

The `projectbluefin` org blocks `github-actions[bot]`-triggered PR workflow runs.
Every workflow fired by the promotion PR (`pull_request` event) gets `action_required`
conclusion — the run is paused waiting for org approval. This means `validate` is never
posted as a passing check, so `gh pr merge --auto` waits forever.

The merge queue fires `merge_group` events instead of `pull_request` events. `merge_group`
is NOT subject to the bot approval policy. `validate` runs clean, passes, and the queue
merges. This is why `use_merge_queue: true` is unconditional — without it, the promotion
PR never merges automatically.

Bluefin uses exactly this pattern. Dakota must match it.

## Ruleset Management

The ruleset cannot be updated via `PATCH /repos/.../rulesets/{id}` with a standard
`repo`-scoped PAT — returns 404. Use DELETE + POST to replace it:

```bash
# Delete old ruleset
curl -X DELETE \
  -H "Authorization: Bearer $(gh auth token)" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/projectbluefin/dakota/rulesets/{OLD_ID}"

# Create new ruleset
curl -X POST \
  -H "Authorization: Bearer $(gh auth token)" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/projectbluefin/dakota/rulesets" \
  -d '{
    "name": "main-merge-queue-no-review",
    "target": "branch",
    "enforcement": "active",
    "conditions": {"ref_name": {"include": ["refs/heads/main"], "exclude": []}},
    "bypass_actors": [
      {"actor_id": null, "actor_type": "OrganizationAdmin", "bypass_mode": "always"},
      {"actor_id": 2740, "actor_type": "Integration", "bypass_mode": "pull_request"},
      {"actor_id": 3069633, "actor_type": "Integration", "bypass_mode": "pull_request"}
    ],
    "rules": [
      {"type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      }},
      {"type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [{"context": "validate", "integration_id": 15368}]
      }},
      {"type": "merge_queue", "parameters": {
        "merge_method": "SQUASH",
        "max_entries_to_build": 2,
        "min_entries_to_merge": 1,
        "max_entries_to_merge": 5,
        "min_entries_to_merge_wait_minutes": 5,
        "grouping_strategy": "ALLGREEN",
        "check_response_timeout_minutes": 120
      }},
      {"type": "non_fast_forward"},
      {"type": "deletion"}
    ]
  }'
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Release gate is red, so publish is broken." | Different layer. Publish may be healthy while promotion is blocked. |
| "Let's just add more checks to the promotion PR." | That slows the queue and duplicates the real stable gate. |
| "`action_required` means rerun the same gate." | It means the org is blocking bot PR runs. Only the merge queue bypasses this. |
| "`use_merge_queue` only needs to be true for schedule/dispatch." | Wrong. It must always be true. The bot approval block applies to push events too. |
| "Adding a required review adds safety." | It permanently blocks every automated promotion PR. |
| "This reusable caller only needs job-level permissions." | Wrong often enough to deserve a scar. Check top-level caller permissions first. |

## Red Flags

- `use_merge_queue` is conditional on `github.event_name`
- `required_approving_review_count` is greater than 0 in ruleset or classic protection
- The ruleset is missing the `merge_queue` rule type
- editing stable-promotion logic while the real failure is earlier publish plumbing
- adding full e2e to the promotion PR path
- rerunning `action_required` workflow runs — they cannot be rerun, they are bot-blocked

## Verification

- [ ] `use_merge_queue: true` unconditionally in `promote-testing-to-main.yml`
- [ ] Ruleset `main-merge-queue-no-review` exists and has `merge_queue` rule
- [ ] Classic branch protection `required_approving_review_count` is 0
- [ ] `run_e2e: false` unchanged in the caller
- [ ] Promotion PR enqueued and merged without any human interaction
- [ ] Weekly cadence remains Tuesday `04:00 UTC`
- [ ] You did not collapse publish, promotion, and stable release into one mental model

## Lessons Learned

### release/blocked after CI-only push to testing is expected

When a paths-ignored push (e.g. `.github/workflows/**` change) advances the `testing`
HEAD, the promote gate runs against the new SHA and finds no CI results for it.
The gate correctly sets `release/blocked` — the SHA has never been built.

This is not a pipeline failure. The resolution is automatic:
1. The BST build for the prior SHA completes.
2. `publish.yml` fires → `:testing` updated.
3. Next promote run re-evaluates → gate passes → merge queue fires.

### One BST build at a time — cancel everything before starting a new build

Before triggering or landing any change that starts a new BST build, cancel ALL
in-progress BST jobs — including cache-warm runs.

```bash
gh run list --repo projectbluefin/dakota --json databaseId,status,name \
  | python3 -c "import json,sys; [print(r['databaseId'], r['name']) for r in json.load(sys.stdin) if r['status'] in ('in_progress','queued','pending')]"
gh run cancel <run-id> --repo projectbluefin/dakota
```

Cache-warm runs are NOT exempt. Cancel everything, let one build finish, then re-trigger warm separately.

### startup_failure on promote dispatch — statuses:write missing in caller (2026-06-23)

**Symptom:** Every `promote-testing-to-main.yml` dispatch returns `startup_failure` before any job runs. No log output available.

**Root cause:** `projectbluefin/actions` updated `reusable-promote-squash.yml@v1` to post a `validate=success` commit status on the squash branch HEAD (so the merge queue accepts the PR in the same run). This requires `statuses: write` in the promote job.

Caller-level `permissions:` sets the **ceiling** for all called workflow jobs. If `statuses: write` is not in the caller's top-level block, GitHub rejects the reusable workflow at startup — no job is queued, no log is written.

**Fix:** Add `statuses: write` to `promote-testing-to-main.yml` permissions:

```yaml
permissions:
  contents: write
  pull-requests: write
  issues: write
  packages: read
  actions: read
  statuses: write       # post validate status on squash branch head
```

**Detection:** When `projectbluefin/actions@v1` adds a new permission to a reusable job, check whether the dakota caller's `permissions:` block covers it. Missing permissions produce `startup_failure` with no log output — not a runtime error.

**Related:** See also `ci-tooling.md` note about `workflows: write` being an invalid actionlint scope (use a GitHub App token instead for workflow file updates).
