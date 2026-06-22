---
name: ci
description: CI entry point for Dakota. Routes agents to the right CI skill fast: workflow map, GitHub Actions tooling failures, e2e/boot checks, release promotion, or merge-queue recovery. Use when the task mentions CI, Actions, publish, promote, release, smoke, boot-check, or startup_failure.
metadata:
  context7-sources:
    - /websites/github_en_actions
    - /bootc-dev/bootc
---

# CI Router

## Overview

This is the **load-first** CI skill. Do not dump the whole CI history into context up front.
Load this file, identify the failure class, then load only the next skill you need.

## When to Use

Use this skill when the task mentions:
- GitHub Actions failures
- `startup_failure`, `action_required`, missing jobs, or flaky checks
- `publish.yml`, `build.yml`, `promote-testing-to-main.yml`, `execute-release.yml`
- boot-check, smoke, testsuite, SBOM, or GHCR publish problems
- merge queue, promotion PRs, or stable release flow

## When NOT to Use

- Element build or packaging failures inside BST → `debugging.md`
- BST syntax, element kinds, or project layout → `buildstream.md`
- OCI image contents or layer assembly → `oci-layers.md`
- Normal PR review → `pr-review.md`

## Core Process

1. **Classify the failure before reading logs.**
   - *Which workflow?* `build`, `publish`, `promote`, `release`, `e2e`, `merge queue`
   - *Which phase?* trigger, setup, reusable workflow call, build/export, boot, smoke, promotion
2. **Load one next skill, not five.**
   - Need workflow/trigger map → `workflow-map.md`
   - Need reusable workflow / permissions / cache-dir weirdness → `ci-tooling.md`
   - Need boot-check / smoke / testsuite behavior → `e2e-ci.md`
   - Need `:testing` → `:stable` / release flow → `release-promotion.md`
   - Need stale PR or queue cleanup → `merge-queue.md`
3. **Read the actual workflow file before editing.**
4. **Verify tool behavior via Context7** for GitHub Actions or bootc when changing syntax/flags.
5. **Write back the lesson** to the narrowest skill file, not this router, unless the routing itself changed.

## Skill Selection Table

| If the problem is about... | Load next |
|---|---|
| Which workflow owns this stage? | `workflow-map.md` |
| `startup_failure`, `jobs: []`, token scopes, reusable workflows | `ci-tooling.md` |
| `actions/cache`, podman bind mounts, runner/runtime quirks | `ci-tooling.md` |
| boot-check, QEMU, `bootc install to-disk`, smoke placement | `e2e-ci.md` |
| promotion PRs, release gate, `action_required`, stable release | `release-promotion.md` |
| conflicting chore PRs, stale queue branches | `merge-queue.md` |
| historical edge cases and deep cuts | `ci-reference.md` |


## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll debug this CI failure without reading the workflow file." | Always read the actual `.github/workflows/*.yml` first. The docs lag reality. |
| "ci.md will have the detailed answer." | ci.md is a router. The answer is in the skill it points to (`ci-reference.md`, `workflow-map.md`, etc.). |
| "`weekly-testing-promotion.yml` exists and I can dispatch it." | That workflow does not exist. Promotion is `promote-testing-to-main.yml` (Tuesdays 04:00 UTC) + manual `production` Environment approval. |
| "`e2e.yml` fires on pull_request with change detection." | No. `e2e.yml` is `workflow_dispatch` only — PRs don't have a published `:testing` build to test against. |
| "The commit prefix for promotion is `ci: promote testing images to stable`." | The actual `execute-release.yml` grep matches `ci(promote): dakota testing` OR `chore: promote testing to main`. |

## Remote Cache Quick Reference

- Endpoint: `cache.projectbluefin.io:11002` (mTLS)
- Credentials: `CASD_CLIENT_CERT` (repo variable) + `CASD_CLIENT_KEY` (repo secret)
- Without credentials: BST builds from source — slower but functional (normal for forks)

## Red Flags

- Dispatching `weekly-testing-promotion.yml` — this workflow does not exist
- Trusting schedule times or trigger conditions from docs without checking the actual workflow `on:` block
- Loading `ci-reference.md` at session start — it is an archive, not a starting point
- Editing CI without running `just validate` first

## Verification

- [ ] Identified the owning workflow from `workflow-map.md` before reading logs
- [ ] Checked actual `on:` triggers in the `.yml` file (not the docs)
- [ ] Loaded only one next skill, not all CI skills
- [ ] Cache endpoint confirmed: `cache.projectbluefin.io:11002`
- [ ] Pre-commit gate: `just bst show oci/bluefin.bst` exits clean

Full CI history and deep cuts: `ci-reference.md`
