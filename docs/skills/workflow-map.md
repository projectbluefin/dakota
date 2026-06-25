---
name: workflow-map
description: Maps Dakota's CI workflows, triggers, and branch flow so agents can identify the owning workflow before debugging. Use when you need to know which workflow should have run, why it did or did not run, or where a publish/promotion stage lives.
metadata:
  context7-sources:
    - /websites/github_en_actions
---

# Workflow Map

## Overview

This skill answers one question fast: **which workflow owns this failure path?**
Use it before log-diving or editing YAML.

## When to Use

Use when you need to answer:
- Which workflow should have run?
- Why did nothing trigger?
- Is this a PR check, merge-queue build, publish, or promotion problem?
- Which branch owns `:testing`, `:stable`, or `:next` behavior?

## When NOT to Use

- Reusable workflow `startup_failure`, token scopes, or cache bind-mount bugs → `ci-tooling.md`
- boot-check, smoke, or testsuite behavior → `e2e-ci.md`
- release gate, promotion PR, or stable promotion flow → `release-promotion.md`

## Core Process

1. **Identify the branch and event.**
   - `pull_request`
   - `merge_group`
   - `workflow_run`
   - `push: testing`
   - `push: main`
   - `workflow_dispatch`
2. **Map the event to the owning workflow.**
3. **Only then inspect logs or edit config.**

## Pipeline Map

```text
PR touching image paths
  ├─ validate (PR syntax / graph checks)
  └─ e2e (testsuite wrapper; change-detected)

Merge queue → testing or next
  └─ build.yml
       └─ publish.yml (workflow_run from build)
            ├─ publish-image
            ├─ boot-check   [hard gate]
            ├─ publish-sbom [parallel]
            └─ promote to :testing / :next / :btw

Daily 13:00 UTC / manual
  └─ build.yml (schedule trigger)
       └─ publish.yml (workflow_run from build)
            └─ promote to :testing

Successful publish.yml on testing
  ├─ publish-smoke.yml
  │    └─ smoke suite [observational only]
  └─ execute-release.yml (workflow_run from publish, testing branch)
       ├─ SHA freshness check (:testing vs :stable digest)
       │    └─ skip if equal (already up to date)
       ├─ cosign verify :testing
       ├─ boot-check gate
       ├─ skopeo copy :testing → :stable
       ├─ fast-forward main bookmark
       └─ create GitHub Release

Successful publish.yml on testing   ← PARALLEL, DECOUPLED
  └─ build-aarch64.yml (workflow_run from publish on testing)
       └─ :aarch64 and :aarch64-<sha> published to GHCR
          (no effect on x86_64 builds, publish, or release)
```

**Deleted workflows (OCI-native redesign, 2026-06-23):** `promote-testing-to-main.yml`, `pr-release-gate.yml`, `sync-main-to-testing.yml`, `cache-warm.yml`.

## Workflow Ownership Table

| Workflow | Owns | Normal trigger |
|---|---|---|
| `.github/workflows/build.yml` | BST build into remote CAS | `merge_group`, `workflow_dispatch`, `schedule: daily 13:00 UTC`. `validate` job runs on `pull_request` only; `build` job skips `pull_request`. Note: `push:` triggers were removed to avoid CAS contention; we rely entirely on the daily schedule to publish streams. |
| `.github/workflows/build-aarch64.yml` | aarch64 OCI build + GHCR push | `workflow_run` from `publish.yml` on `testing`, `workflow_dispatch`. Fully decoupled — never in `needs:` of publish/promote/release. |
| `.github/workflows/publish.yml` | export, sign, boot-check, promote tags | `workflow_run` from build |
| `.github/workflows/publish-smoke.yml` | observational smoke only | `workflow_run` from publish |
| `.github/workflows/e2e.yml` | PR-facing testsuite check | `pull_request` |
| `.github/workflows/execute-release.yml` | SHA freshness check → cosign verify → boot-check → stable release | `workflow_run` from `publish.yml` on `testing`, `workflow_dispatch`. Skips if `:testing` digest equals `:stable` digest. |
| `.github/workflows/sync-next-from-main.yml` | merge main into next (preserve junction refs) | `push: main`, `workflow_dispatch` |
| ~~`promote-testing-to-main.yml`~~ | DELETED | Was: `push: testing`, schedule, manual |
| ~~`pr-release-gate.yml`~~ | DELETED | Was: `pull_request` to `main` |
| ~~`sync-main-to-testing.yml`~~ | DELETED | Was: `push: main` |
| ~~`cache-warm.yml`~~ | DELETED | Was: Mon/Thu 06:00 UTC schedule |

## Branch / Tag Map

| Branch | Trigger | Published tag(s) | Notes |
|---|---|---|---|
| `testing` | `schedule: 13:00 UTC` | `:testing` | **Development trunk. Primary `:testing` publish path.** Builds on schedule using CAS warmed by merge queue. |
| `main` | fast-forward from `execute-release.yml` | `:stable` | **Release bookmark only.** Only `execute-release.yml` writes here after a successful SHA freshness check + cosign verify + boot-check. No PRs target `main`. |
| `next` | `schedule: 03:00 UTC` (via `nightly-next-build.yml`) | `:next`, `:btw` | Rolling GNOME master; never stable. No PR requirement on branch protection. |
| `gh-readonly-queue/testing/*` | merge-queue | (build only, no tag) | Gate before merge to `testing`. |
| `gh-readonly-queue/next/*` | merge-queue | (build only, no tag) | Gate before merge to `next`. |
| `testing` (BST paths) | `workflow_run` from publish | `:aarch64`, `:aarch64-<sha>` | Published by `build-aarch64.yml`. Completely decoupled from x86_64 flow. Never blocks release. |

**What testing does (not just PRs):**
```
daily 13:00 UTC schedule
  → build.yml (build job using CAS warmed by merge queue)
  → publish.yml (workflow_run)
      → :testing tag published to GHCR
  → execute-release.yml (workflow_run from publish on testing)
      → SHA freshness check → cosign verify → boot-check
      → skopeo copy :testing → :stable
      → fast-forward main bookmark
  → build-aarch64.yml (workflow_run from publish on testing)
      → :aarch64 / :aarch64-<sha> published (decoupled, never blocks release)
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Publish failed, so build must be broken." | Often false. Build, publish, boot, smoke, and promotion are separate stages. |
| "Nothing ran, so GitHub is flaky." | Usually the trigger or branch filter is wrong. |
| "The schedule still owns :testing." | This is correct. The daily schedule is the only way `:testing` updates (as of 2026-06-25) to avoid global CAS locks. |

## Red Flags

- Debugging `publish.yml` when the branch only ever hits `e2e.yml`
- Treating `testing` as the branch that publishes stable directly
- Editing a workflow before checking whether a different workflow actually owns the stage
- Assuming `workflow_dispatch` behaves like `workflow_run`
- A branch-sync workflow that only lives on the target branch (will never fire — must be on default branch)
- Re-adding PR requirement to `next` branch protection (breaks `sync-next-from-main` direct push)

## Verification

- [ ] You can name the owning workflow for the failing stage
- [ ] You can state the trigger event and branch filter
- [ ] You know whether the signal is PR-time, merge-time, publish-time, or promotion-time
- [ ] You loaded a narrower follow-up skill before touching YAML
