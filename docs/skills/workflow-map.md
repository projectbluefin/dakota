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

Merge queue → main or next
  └─ build.yml
       └─ publish.yml (workflow_run from build)
            ├─ publish-image
            ├─ boot-check   [hard gate]
            ├─ publish-sbom [parallel]
            └─ promote to :testing / :next / :btw

Successful publish.yml
  └─ publish-smoke.yml
       └─ smoke suite [observational only]

push: testing / weekly Tuesday 04:00 UTC / manual
  └─ promote-testing-to-main.yml
       └─ opens or updates promotion PR
            └─ pr-release-gate.yml on that PR

merge promotion PR to main
  └─ execute-release.yml
       ├─ stable tag copy + release notes
       └─ create-multiarch-stable [continue-on-error, ARM never blocks]

push: testing/main (BST paths) / Tuesday 04:00 UTC / manual   ← PARALLEL, DECOUPLED
  └─ build-aarch64.yml [continue-on-error throughout]
       └─ :aarch64 and :aarch64-<sha> published to GHCR
          (no effect on x86_64 builds, publish, promote, or release)
```

## Workflow Ownership Table

| Workflow | Owns | Normal trigger |
|---|---|---|
| `.github/workflows/build.yml` | BST build into remote CAS | `push: main/next/testing` (paths-ignore: docs, workflows, md), `merge_group`, `workflow_dispatch`. `validate` job runs on `pull_request` only; `build` job skips `pull_request`. |
| `.github/workflows/build-aarch64.yml` | aarch64 OCI build + GHCR push | `push: main/testing` (same paths-ignore as build.yml), `schedule: Tuesday 04:00 UTC`, `workflow_dispatch`. Fully decoupled — never in `needs:` of publish/promote/release. |
| `.github/workflows/publish.yml` | export, sign, boot-check, promote tags | `workflow_run` from build |
| `.github/workflows/publish-smoke.yml` | observational smoke only | `workflow_run` from publish |
| `.github/workflows/e2e.yml` | PR-facing testsuite check | `pull_request` |
| `.github/workflows/promote-testing-to-main.yml` | open/update promotion PR | `push: testing`, schedule, manual |
| `.github/workflows/pr-release-gate.yml` | promotion PR gate | `pull_request` to `main` |
| `.github/workflows/execute-release.yml` | stable release execution | `push: main`, `workflow_dispatch`. `check-trigger` job gates on commit message matching `^ci\(promote\): dakota testing` or `^chore: promote testing to main`; `workflow_dispatch` bypasses the gate. |
| `.github/workflows/sync-next-from-main.yml` | merge main into next (preserve junction refs) | `push: main`, `workflow_dispatch` |

## Branch / Tag Map

| Branch | Trigger | Published tag(s) | Notes |
|---|---|---|---|
| `testing` | `push` (BST-affecting paths only) | `:testing` | **Primary `:testing` publish path.** Every BST-affecting push builds → publishes → promotes. Doc/workflow-only pushes are ignored (paths-ignore). |
| `main` | merge of promotion PR | `:latest`, `:stable` | Only via `execute-release.yml` and only when commit message starts with `ci: promote testing images to stable`. Normal merges do NOT produce a new tag. |
| `next` | `push` or `sync-next-from-main` dispatch | `:next`, `:btw` | Rolling GNOME master; never stable. No PR requirement on branch protection. |
| `gh-readonly-queue/main/*` | merge-queue | (build only, no tag) | Gate before merge to `main`. |
| `gh-readonly-queue/next/*` | merge-queue | (build only, no tag) | Gate before merge to `next`. |
| `testing` or `main` (BST paths) | `push`, Tuesday schedule, dispatch | `:aarch64`, `:aarch64-<sha>` | Published by `build-aarch64.yml`. Completely decoupled from x86_64 flow. Never blocks release. |

**What testing does (not just PRs):**
```
push to testing (BST-affecting)
  → build.yml (build job)
  → publish.yml (workflow_run)
      → :testing tag published to GHCR
  → promote-testing-to-main.yml
      → opens/updates auto/promote-testing-to-main PR
           → pr-release-gate.yml gates it
           → auto-merge → push to main
               → execute-release.yml → :stable / :latest
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Publish failed, so build must be broken." | Often false. Build, publish, boot, smoke, and promotion are separate stages. |
| "Nothing ran, so GitHub is flaky." | Usually the trigger or branch filter is wrong. |
| "The schedule still owns :testing." | Not anymore. Every successful merge publishes immediately. |

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
