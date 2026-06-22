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

push: testing (BST-changing paths) / merge_group: testing
  └─ build.yml
       └─ publish.yml (workflow_run from build)
            ├─ publish-image → :$sha
            ├─ boot-check   [hard gate]
            ├─ publish-sbom [parallel]
            └─ promote → :testing

push: testing / nightly / manual
  └─ promote-testing-to-main.yml
       └─ opens or updates promotion PR (testing → main)
            └─ pr-release-gate.yml on that PR

merge promotion PR to main (weekly Tuesday, e2e-gated)
  └─ execute-release.yml
       └─ stable tag copy + release notes → :latest / :stable

push: next (BST-changing paths) / merge_group: next
  └─ build.yml → publish.yml → :next / :btw (never stable)

Successful publish.yml
  └─ publish-smoke.yml
       └─ smoke suite [observational only]
```

## Workflow Ownership Table

| Workflow | Owns | Normal trigger |
|---|---|---|
| `.github/workflows/build.yml` | BST build into remote CAS | `push: testing/main/next` (BST-changing), `merge_group`, `workflow_dispatch` |
| `.github/workflows/publish.yml` | export, sign, boot-check, promote tags | `workflow_run` from build (testing/main/next branches) |
| `.github/workflows/publish-smoke.yml` | observational smoke only | `workflow_run` from publish |
| `.github/workflows/e2e.yml` | PR-facing testsuite check | `pull_request` |
| `.github/workflows/promote-testing-to-main.yml` | open/update promotion PR | `push: testing`, schedule, manual |
| `.github/workflows/pr-release-gate.yml` | promotion PR gate | `pull_request` to `main` |
| `.github/workflows/execute-release.yml` | stable release execution | `push: main`, manual |
| `.github/workflows/sync-next-from-main.yml` | merge main into next (preserve junction refs) | `push: main`, `workflow_dispatch` |

## Branch / Tag Map

This is the authoritative model per AGENTS.md. Do not change build.yml to contradict it.

| Branch | Publishes | How |
|---|---|---|
| `testing` | `:testing` | Every BST-changing push triggers build.yml → publish.yml → `:testing`. GHA-only and docs changes are filtered by paths-ignore. |
| `main` | `:latest` / `:stable` | Weekly Tuesday promotion squash PR from `testing`. Requires 2 human approvals in `production` Environment. |
| `next` | `:next` / `:btw` | Every BST-changing push, rolling GNOME master. Never promoted to stable. |
| `gh-readonly-queue/testing/*` | `:testing` | Merge-queue build path for `testing` |
| `gh-readonly-queue/main/*` | triggers publish chain | Merge-queue build path for `main` |
| `gh-readonly-queue/next/*` | `:next` | Merge-queue build path for `next` |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Publish failed, so build must be broken." | Often false. Build, publish, boot, smoke, and promotion are separate stages. |
| "Nothing ran, so GitHub is flaky." | Usually the trigger or branch filter is wrong. |
| "build.yml only fires on merge_group." | **WRONG. It also fires on push to testing/main/next (BST-changing paths).** Removing this push trigger breaks :testing publishing. |
| "The push trigger is redundant with merge_group." | **WRONG. The push trigger IS the :testing publish path.** merge_group handles PR validation; push handles image publishing. |

## Red Flags

- **Removing `testing` from `build.yml` push.branches** — this kills `:testing` publishing entirely
- **Adding `testing` to merge_group only** — PRs validate but merges never publish
- Debugging `publish.yml` when the branch only ever hits `e2e.yml`
- Editing a workflow before checking whether a different workflow actually owns the stage
- Assuming `workflow_dispatch` behaves like `workflow_run`
- A branch-sync workflow that only lives on the target branch (will never fire — must be on default branch)
- Re-adding PR requirement to `next` branch protection (breaks `sync-next-from-main` direct push)

## Hard Rule — Do Not Remove push: testing

`build.yml` must always include `testing` in `push.branches`. This is the trigger that publishes `:testing` on every merge. Agents have removed this trigger at least twice (PR #997, each time diagnosed as "redundant" — it is not redundant, it is the primary publish path). If you see it missing, add it back. Do not open a PR to remove it.

## Verification

- [ ] You can name the owning workflow for the failing stage
- [ ] You can state the trigger event and branch filter
- [ ] You know whether the signal is PR-time, merge-time, publish-time, or promotion-time
- [ ] You loaded a narrower follow-up skill before touching YAML
