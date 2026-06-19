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

push: testing / nightly / manual
  └─ promote-testing-to-main.yml
       └─ opens or updates promotion PR
            └─ pr-release-gate.yml on that PR

merge promotion PR to main
  └─ execute-release.yml
       └─ stable tag copy + release notes
```

## Workflow Ownership Table

| Workflow | Owns | Normal trigger |
|---|---|---|
| `.github/workflows/build.yml` | BST build into remote CAS | `merge_group`, `workflow_dispatch` |
| `.github/workflows/publish.yml` | export, sign, boot-check, promote tags | `workflow_run` from build |
| `.github/workflows/publish-smoke.yml` | observational smoke only | `workflow_run` from publish |
| `.github/workflows/e2e.yml` | PR-facing testsuite check | `pull_request` |
| `.github/workflows/promote-testing-to-main.yml` | open/update promotion PR | `push: testing`, schedule, manual |
| `.github/workflows/pr-release-gate.yml` | promotion PR gate | `pull_request` to `main` |
| `.github/workflows/execute-release.yml` | stable release execution | `push: main`, manual |
| `.github/workflows/cache-warm.yml` | warm CAS for later queue builds | schedule, manual |

## Branch / Tag Map

| Branch | Result |
|---|---|
| `main` | merged changes build, publish `:$sha`, then promote to `:testing` |
| `testing` | source branch for promotion PRs into `main` |
| `next` | rolling GNOME master stream; publish to `:next` and `:btw`, never stable |
| `gh-readonly-queue/main/*` | merge-queue build path for `main` |
| `gh-readonly-queue/next/*` | merge-queue build path for `next` |

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

## Verification

- [ ] You can name the owning workflow for the failing stage
- [ ] You can state the trigger event and branch filter
- [ ] You know whether the signal is PR-time, merge-time, publish-time, or promotion-time
- [ ] You loaded a narrower follow-up skill before touching YAML
