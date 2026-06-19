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

## Red Flags

- `permissions: {}` on a reusable workflow caller
- `startup_failure` with no jobs inspected
- podman `statfs ... no such file or directory`
- trying to use `continue-on-error` to tame a reusable-workflow call job
- relying on `GITHUB_TOKEN` for bot PRs that need PR checks to fire

## Verification

- [ ] You checked whether the run had `jobs: []`
- [ ] You inspected top-level caller permissions before editing nested jobs
- [ ] Any podman bind-mounted cache dir is created explicitly
- [ ] Required checks are aligned with `pull_request` visibility
- [ ] The fix reduces CI ambiguity instead of adding more magic
