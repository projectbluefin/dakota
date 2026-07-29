---
name: merge-queue
description: Getting Dakota PRs through the merge queue — required checks that must fire on both PR and queue events, rebasing conflicting branches, and refreshing stale auto/track automation branches. Load when a PR will not enter or clear the queue.
---

# Merge Queue

## Overview

Dakota merges through a GitHub merge queue. The always-on gate is the
`Validate` workflow, which runs on both `pull_request` and `merge_group` — a
check that fires on only one of those events can never satisfy the other. The
full image build is deliberately excluded from queue gating; its cost and the
global build lock make it a bad fit for a check that is cancelled the moment
the PR merges.

## When to use

- A PR cannot be queued, or the queue rejects it
- A required check never posted
- An `auto/track-*` automation PR is conflicting, stale, or empty
- Deciding whether a new workflow should become a required check

## When not to use

- Deciding whether the failure is queue-related → [ci-triage](../ci-triage/SKILL.md)
- Token or permission errors on the check itself → [ci-tooling](../ci-tooling/SKILL.md)
- Reviewing the PR's content → [pr-review](../pr-review/SKILL.md)

## Authoritative sources

- `.github/workflows/validate.yml` — the gate; note its event list
- `.github/workflows/build.yml` — states why the build is not a queue gate
- `.github/workflows/pr-triage.yml` — target-branch enforcement and labels
- `.github/workflows/pr-autoupdate.yml` — keeps open PRs from falling behind
- `.github/workflows/track-bst-sources.yml`, `track-next-junctions.yml` —
  how `auto/track-*` branches are created and refreshed

## Workflow

1. **Read the PR's merge state before doing anything.**
   `gh pr view <N> --repo projectbluefin/dakota --json mergeStateStatus,statusCheckRollup`.
2. **If a required check is missing,** confirm the workflow that provides it
   runs on the event in question. Adding a check to the ruleset without the
   matching `merge_group` trigger deadlocks every PR.
3. **If the base branch is wrong,** retarget rather than argue with CI —
   `pr-triage.yml` fails the PR and comments with the correct target.
4. **If the branch is `CONFLICTING`,** first check whether it is a same-repo
   branch or a fork PR — `gh pr view <N> --json headRepositoryOwner,maintainerCanModify`.
   - Same-repo branch (e.g. `auto/track-*`): rebase it onto the base branch
     and force-push with `--force-with-lease`. If the rebase leaves nothing,
     close the PR: the change is already on the base.
   - Fork PR: only force-push if `maintainerCanModify` is `true` (or you have
     confirmed write access to the fork) — add the fork as a remote and push
     there. If `maintainerCanModify` is `false` or push access is unavailable,
     do not assume access: ask the contributor to rebase and force-push their
     own branch instead.
5. **For an `auto/track-*` PR, re-run its tracker instead of hand-fixing it.**
   The tracker recreates the branch from the current base and force-pushes,
   so a manual merge commit on that branch is discarded on the next run.
6. **Merge in waves.** Each merge advances the base and puts the remaining
   PRs behind it; re-list and let the auto-update workflow catch up before
   queueing the next batch.

## Failure modes

### A check that runs only on `pull_request`

Bot-authored PRs are the first to expose this: the organization may hold
first-party Actions runs on bot PRs for approval, while the queue still
requires the check to have been posted. Keeping the gate on both events is
structural, not a convenience.

### Automerge keyed to a workflow that never runs on PR commits

Automerge matches a PR by the head SHA of a completed workflow run, so it
must subscribe to a workflow that actually runs on PR commits. Subscribing it
to the image build — which runs on schedule and dispatch — matches trunk SHAs
and silently never fires.

### Queued auto-merge does not honour merge bypasses

GitHub's auto-merge queue ignores bypass allowances that a direct merge
honours. Automation that is meant to merge immediately under a bypass has to
perform a direct squash merge; automation that must wait for checks uses the
auto-merge path. Mixing them up produces PRs that sit open forever.

### A stale automation branch that is no longer produced

Promotion is an OCI tag copy and creates no promotion branch, so any leftover
`auto/promote-*` branch is residue — the post-release verification step warns
about them. Delete them; do not build process around them.

## Verification

```bash
# Merge state and check rollup for a PR
gh pr view <N> --repo projectbluefin/dakota --json mergeStateStatus,statusCheckRollup

# The gate must list both PR and queue events
rg -n -A6 '^on:' .github/workflows/validate.yml

# Is a rebased branch actually ahead of its base?
gh api repos/projectbluefin/dakota/compare/testing...<branch> --jq '{ahead: .ahead_by}'

# Which branches the automation trackers create
rg -n 'auto/track-' .github/workflows
```

## Related skills

- [ci-triage](../ci-triage/SKILL.md) — routing before you debug the queue
- [ci-tooling](../ci-tooling/SKILL.md) — tokens behind bot PRs and checks
- [pr-review](../pr-review/SKILL.md) — what a PR must satisfy before merge
- [update-refs](../update-refs/SKILL.md) — what the tracker PRs are bumping
