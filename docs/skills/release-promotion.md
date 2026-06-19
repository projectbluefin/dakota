---
name: release-promotion
description: Dakota publish and promotion flow from main to testing to stable, including promotion PRs, release gate behavior, and manual recovery. Use when working on promotion workflows, action_required gates, release execution, or stable-cut logic.
metadata:
  context7-sources:
    - /websites/github_en_actions
    - /bootc-dev/bootc
---

# Release Promotion

## Overview

Dakota has **two promotion layers**:
1. `main` merge → publish → `:testing`
2. `testing` → promotion PR → stable release execution

Do not conflate "publish is healthy" with "stable promotion is healthy".

## When to Use

Use when the task mentions:
- `promote-testing-to-main.yml`
- `pr-release-gate.yml`
- `execute-release.yml`
- promotion PRs from `auto/promote-testing-to-main`
- `action_required` release gates
- stable release, `:latest`, `:stable`, or promotion PR flow

## When NOT to Use

- Need to know which workflow owns a stage → `workflow-map.md`
- Workflow never starts because of caller permissions or cache plumbing → `ci-tooling.md`
- Boot-check or smoke mechanics → `e2e-ci.md`

## Core Process

1. **Identify the stage.**
   - publish to `:testing`
   - open/update promotion PR
   - gate the promotion PR
   - execute stable release after merge
2. **Check whether the gate is real or infrastructure.**
   - `action_required` on a promotion PR often means the gate is waiting on policy or verification, not that the YAML crashed.
3. **For promotion PR workflows, inspect reusable caller permissions first.**
4. **Do not add e2e back into the promotion PR path.**
   Dakota intentionally gates stable at the later human-approved release stage.
5. **For manual recovery, re-run the failed publish/promote workflow that owns the stage, not some nearby check.**

## Promotion Map

```text
main merge
  → build.yml
  → publish.yml
  → :testing
  → push testing / nightly / manual
  → promote-testing-to-main.yml
  → auto/promote-testing-to-main PR
  → pr-release-gate.yml
  → merge promotion PR
  → execute-release.yml
  → :latest / :stable + release notes
```

## Hard Rules

- `promote-testing-to-main.yml` is a thin caller. Treat caller-level `permissions:` as critical.
- `pr-release-gate.yml` must not starve the reusable gate token.
- Promotion PRs do **not** run the full e2e quality gate; that belongs at the later stable promotion stage.
- When a gate is `action_required`, inspect what policy condition it is waiting on before editing workflow code.

## Manual Recovery Shortcuts

```bash
# open promotion PR status
gh pr list --repo projectbluefin/dakota \
  --search 'head:auto/promote-testing-to-main state:open'

# recent gate runs
gh run list --repo projectbluefin/dakota --workflow 'PR Release Gate' --limit 10

# recent promote runs
gh run list --repo projectbluefin/dakota --workflow 'Promote testing to main' --limit 10
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Release gate is red, so publish is broken." | Different layer. Publish may be healthy while promotion is blocked. |
| "Let's just add more checks to the promotion PR." | That slows humans and duplicates the real stable gate. |
| "`action_required` means rerun the same gate." | Usually it means read the gate condition first. |
| "This reusable caller only needs job-level permissions." | Wrong often enough to deserve a scar. Check top-level caller permissions first. |

## Red Flags

- editing stable-promotion logic while the real failure is earlier publish plumbing
- adding full e2e to the promotion PR path
- rerunning arbitrary nearby workflows instead of the owning stage
- ignoring `auto/promote-testing-to-main` PR state and debugging the wrong branch

## Verification

- [ ] You identified the exact promotion stage that is failing
- [ ] You checked open promotion PR state before editing YAML
- [ ] Reusable caller permissions were validated if the gate did not start
- [ ] You did not collapse publish, promotion, and stable release into one mental model
- [ ] Any change preserves the factory's intended human approval gates
