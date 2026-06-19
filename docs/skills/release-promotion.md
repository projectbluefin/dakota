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

---

## How stable releases work

The stable release is **driven entirely by the promotion PR**. The flow is:

1. `promote-testing-to-main.yml` runs (on push to `testing`, nightly, or manual dispatch)
   and opens/updates the `auto/promote-testing-to-main` PR.
2. A maintainer reviews the PR and approves it **at their discretion**.
3. Approval triggers auto-merge → the squash commit lands on `main`.
4. `execute-release.yml` detects the promotion commit and runs `reusable-execute-release.yml`
   → `:stable` and `:latest` OCI tags are updated and a GitHub Release is created.

**There is no separate "cut a release" command.** The maintainer's approval on
the promotion PR IS the release action.

The `workflow_dispatch` path on `execute-release.yml` exists as a break-glass
fallback only. Do not use it routinely — use it only when the promotion PR
pipeline is broken and a release cannot wait.

---

## Lessons Learned

### execute-release.yml trigger pattern was wrong — automated promotion was broken (2026-06-19)

`execute-release.yml` checked for `^ci: promote testing images to stable` but
the squash commit that lands on `main` from the promotion PR has title
`chore: promote testing to main` (set by `reusable-promote-squash.yml`).

This mismatch meant `execute-release.yml` NEVER fired automatically from a
promotion PR merge. Every stable release required a manual `workflow_dispatch`.

**Fix:** Updated `execute-release.yml` check-trigger to match the actual commit
patterns:
```
^ci\(promote\): dakota testing
^chore: promote testing to main
```

---

### Never close a promotion PR with maintainer approval (2026-06-19)

**Mistake:** Closing PR #901 (promotion PR with ahmed's approval) because its
squash branch was deleted, then re-running promote which found testing=main and
opened no new PR, leaving no path to the release.

**Rule:** If the squash branch is deleted with an open promotion PR, rebuild the
branch — do not close the PR. Re-run `promote-testing-to-main.yml`: if the
branch content is unchanged it will skip the force-push and preserve the approval.

**Recovery if promotion PR was incorrectly closed:**
```bash
gh workflow run promote-testing-to-main.yml --repo projectbluefin/dakota
# If testing == main tree and promote says "nothing to promote", use break-glass:
gh workflow run execute-release.yml --repo projectbluefin/dakota
```
