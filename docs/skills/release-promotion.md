---
name: release-promotion
description: Dakota publish and promotion flow from testing to stable, including the daily OCI-native execute-release flow, SHA-based freshness check, cosign verify, boot-check gate, and manual recovery. Use when working on execute-release.yml, stable promotion failures, branch bookmark state, or the daily build pipeline.
metadata:
  context7-sources:
    - /websites/github_en_actions
    - /bootc-dev/bootc
---

# Release Promotion

## Overview

Promotion from `testing` to `:stable` is **fully automated and daily** — no human approval required at any stage.

```text
testing (trunk) → build.yml → publish.yml → :testing tag
                                                  │
                                         execute-release.yml (workflow_run from publish)
                                         SHA freshness check → cosign verify → boot-check
                                                  │
                                         :stable + fast-forward main bookmark
```

`main` is a release bookmark only. It is fast-forwarded by `execute-release.yml` after each successful promotion. Do not open PRs against `main`.

Do not conflate "publish is healthy" with "stable promotion is healthy".

## When to Use

Use when the task mentions:
- `execute-release.yml`
- stable promotion failures (`:testing` not promoted to `:stable`)
- SHA-based freshness check or `workflow_run` from `publish.yml`
- `main-bookmark-protection` ruleset
- cosign verify in the release path
- stable release, `:stable`, or daily promotion flow
- `testing-merge-queue-no-review` ruleset

## When NOT to Use

- Need to know which workflow owns a stage → `workflow-map.md`
- Workflow never starts because of caller permissions or cache plumbing → `ci-tooling.md`
- Boot-check or smoke mechanics → `e2e-ci.md`

## Core Process

1. **Run the CI pre-flight first.** Verify `OK: field is clear` before any action.
   See Hard Rule #9 in `.github/copilot-instructions.md`. No exceptions.
2. **Identify the stage.**
   - boot-check gate (in `publish.yml` — gates `:testing` promotion)
   - publish to `:testing`
   - `execute-release.yml` SHA freshness check
   - cosign verify `:testing`
   - skopeo copy `:testing` → `:stable`
   - fast-forward `main` bookmark
3. **`execute-release.yml` fires via `workflow_run` from `publish.yml` on the `testing` branch.**
   It checks whether the SHA published as `:testing` differs from the current `:stable`. If
   they are equal, promotion is skipped (already up to date). If they differ, cosign verify
   runs, then the copy and fast-forward. The image is already boot-checked by `publish.yml`.
4. **`workflow_run` from publish — not a push trigger.** `execute-release.yml` starts
   automatically after every successful `publish.yml` run on the `testing` branch. No cron
   or commit-message gate required.
5. **Do not add a promotion PR or merge queue step.** The squash PR ceremony was eliminated
   in the OCI-native redesign (issue 1073). Promotion is a direct OCI tag copy + git
   fast-forward; there is no PR to gate.
6. **For manual recovery, dispatch `execute-release.yml` directly** after verifying the
   `:testing` image is fresh and cosign-verified.

## Promotion Map

```text
push to testing (BST-affecting paths)
  → build.yml (build job, including daily 13:00 UTC schedule)
  → publish.yml (workflow_run)
      → boot-check gate (must boot before :testing is promoted)
      → :testing tag published to GHCR
  → execute-release.yml (workflow_run from publish on testing)
      → SHA freshness check (:testing SHA vs :stable SHA)
          → skip if equal (already up to date)
          → cosign verify :testing
          → skopeo copy :testing → :stable
          → fast-forward main bookmark
          → create GitHub Release
```

## Branch Protection and Ruleset State

### testing (development trunk)

Ruleset: `testing-merge-queue-no-review`

| Rule | Value |
|---|---|
| Required reviews | 0 (fully automated) |
| Required status checks | `validate` (single context, integration_id 15368) |
| Merge queue | enabled |
| Force push | blocked |
| Deletion | blocked |
| Default branch | Yes — `testing` is the GitHub default branch |

**Ground truth (verified via `gh api repos/projectbluefin/dakota/rulesets/18053489`):**
- The only required status check context on `testing` is `validate`.
- `e2e` and `Boot check — gate` from `publish.yml` are **not** ruleset-enforced gates. They run as part of `publish.yml` post-merge and gate stream-tag movement / promotion, not merge-queue entry.
- If you want `Boot check — gate` to block merge-queue entry, that is a Design Gate change to the ruleset — do not modify in passing.

### main (release bookmark)

Ruleset: `main-bookmark-protection`

| Rule | Value |
|---|---|
| Required reviews | none |
| Required status checks | none |
| Merge queue | none |
| Non-fast-forward | blocked |
| Deletion | blocked |

`main` accepts only fast-forward commits from `execute-release.yml`. No PRs target `main`.

**Never add required review counts or merge queue rules to the main bookmark ruleset.** No PRs should ever land on `main` directly.

## Workflow Configuration

`execute-release.yml` fires via `workflow_run` from `publish.yml` on the `testing` branch:

```yaml
on:
  workflow_run:
    workflows: ["Publish Bluefin dakota"]
    branches: [testing]
    types: [completed]
  workflow_dispatch: {}
```

The first job reads `head_sha` from the triggering `workflow_run` event — never the floating `:testing` tag. This anchors cosign verify and the freshness check to the exact SHA that was just built and published.

```yaml
steps:
  - name: Get tested SHA
    id: tested-sha
    run: echo "sha=${{ github.event.workflow_run.head_sha }}" >> "$GITHUB_OUTPUT"
```

Do not substitute `github.event.workflow_run.head_sha` with a `skopeo inspect` lookup of `:testing` — that is a TOCTOU race. Use the event SHA.

## Hard Rules

- `execute-release.yml` must use `head_sha` from the `workflow_run` event, not a floating `:testing` tag lookup.
- `main` is a bookmark only. No PRs target main. `execute-release.yml` is the only writer.
- The `main-bookmark-protection` ruleset must block non-fast-forward and deletion. No merge queue, no required checks.
- The `testing-merge-queue-no-review` ruleset must require `validate` + `e2e` and enable the merge queue.
- Stable promotion cadence is daily — triggered by `workflow_run` from `publish.yml` after each successful build.
- The SHA freshness check compares the `:testing` SHA with the current `:stable` SHA. Equal → skip. Different → promote.
- cosign `--certificate-identity-regexp` must be anchored with `^...$` and restricted to the publishing workflow file.
- `execute-release.yml` `workflow_dispatch` bypass is allowed for manual recovery only.

## Manual Recovery Shortcuts

```bash
# check recent execute-release runs
gh run list --repo projectbluefin/dakota --workflow 'Execute Release' --limit 10

# check recent publish runs (execute-release fires after these)
gh run list --repo projectbluefin/dakota --workflow 'Publish Bluefin dakota' --limit 10

# dispatch execute-release manually (bypasses freshness check — use only for recovery)
gh workflow run execute-release.yml --repo projectbluefin/dakota --ref testing

# verify ruleset state
gh api repos/projectbluefin/dakota/rulesets | jq '[.[] | {id, name}]'

# inspect main bookmark (should match last :stable SHA)
gh api repos/projectbluefin/dakota/branches/main | jq '.commit.sha'

# compare :testing and :stable digests
skopeo inspect docker://ghcr.io/projectbluefin/dakota:testing | jq '.Digest'
skopeo inspect docker://ghcr.io/projectbluefin/dakota:stable  | jq '.Digest'
```

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
  -d '{ ... }'
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "execute-release failed, so publish is broken." | Different layer. Publish may be healthy while promotion is blocked. |
| "Let's use the floating :testing tag as the anchor." | TOCTOU race. Always use `head_sha` from the `workflow_run` event. |
| "main has diverged — let's open a PR to fix it." | main is a bookmark. Only `execute-release.yml` writes to it via fast-forward. |
| "The freshness check is too conservative." | Equal SHAs mean `:stable` is already current. Promotion is not needed. |
| "This reusable caller only needs job-level permissions." | Wrong often enough to deserve a scar. Check top-level caller permissions first. |

## Red Flags

- `execute-release.yml` using `skopeo inspect :testing` to get the SHA instead of `github.event.workflow_run.head_sha`
- Any PR targeting `main` (main is a bookmark, not a development branch)
- Adding a merge queue or required checks to the `main-bookmark-protection` ruleset
- `testing-merge-queue-no-review` ruleset missing `validate` or `e2e` required checks
- Editing stable-promotion logic while the real failure is earlier in publish plumbing

## Verification

- [ ] `execute-release.yml` trigger is `workflow_run` from `publish.yml` on `testing`
- [ ] `head_sha` from `workflow_run` event anchors cosign verify and the freshness check
- [ ] `main-bookmark-protection` ruleset: non_fast_forward + deletion blocked, no merge queue
- [ ] `testing-merge-queue-no-review` ruleset: `validate` + `e2e` required, merge queue enabled
- [ ] No PRs exist targeting `main`
- [ ] `testing` is the GitHub default branch
- [ ] Stable promoted without any human interaction after a successful publish

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
in-progress BST jobs.

```bash
gh run list --repo projectbluefin/dakota --json databaseId,status,name \
  | python3 -c "import json,sys; [print(r['databaseId'], r['name']) for r in json.load(sys.stdin) if r['status'] in ('in_progress','queued','pending')]"
gh run cancel <run-id> --repo projectbluefin/dakota
```

Cancel everything, let one build finish, then re-trigger if needed.

### OCI-native daily promotion model (2026-06-23)

Dakota migrated from a weekly squash-PR ceremony to a daily OCI-native promotion
flow (issue 1073). The key differences:

- **Deleted workflows:** `promote-testing-to-main.yml`, `pr-release-gate.yml`,
  `sync-main-to-testing.yml`, `cache-warm.yml`.
- **`execute-release.yml`** now fires via `workflow_run` from `publish.yml` on the
  `testing` branch — no cron, no commit-message gate.
- **SHA anchor:** `head_sha` from the `workflow_run` event is the source of truth for
  cosign verify and the freshness check. Never use `skopeo inspect :testing` as the
  anchor — that is a TOCTOU race.
- **Freshness check:** compare the `:testing` digest to the `:stable` digest. Equal →
  skip promotion (already up to date). Different → promote.
- **`main` is a bookmark.** Fast-forwarded by `execute-release.yml` only. No PRs
  target `main`. The `main-bookmark-protection` ruleset enforces this.
- **`testing` is the development trunk.** All contributor, Renovate, and BST source
  bump PRs target `testing`. The `testing-merge-queue-no-review` ruleset requires
  `validate` + `e2e` and enables the merge queue.
- **Daily build schedule:** `build.yml` has a `schedule: '0 13 * * *'` trigger that
  fires at 13:00 UTC daily, keeping CAS warm and ensuring a fresh `:testing` each
  day even without a code push.
- **ARM trigger change:** `build-aarch64.yml` now fires via `workflow_run` from
  `publish.yml` — not a Tuesday cron. This serializes ARM after x86 CAS writes
  complete, preventing CAS contention.

## Rollback

When a promoted `:stable` image regresses behaviour or ships a security issue
that cannot wait for the next promotion cycle, use the
[`rollback-stable.yml`](../../.github/workflows/rollback-stable.yml) workflow
instead of running `skopeo copy` from a laptop. The workflow re-uses the same
cosign identity gate that gates promotion, so a rollback cannot smuggle in an
image that was never legitimately published.

### When to use it

- A bug or regression escaped the testing → stable promotion and is hitting
  users on `:stable` / `:stable-multiarch`.
- A supply-chain incident requires reverting to a known-good digest fast.
- **Not** for cosmetic / "I'd rather have yesterday's build" preferences —
  rollback breaks the linear `main`-bookmark history users expect.

### How to invoke

1. Find a target SHA that previously held `:stable`. Successful
   `execute-release.yml` runs are the canonical source:

   ```bash
   gh run list \
     --repo projectbluefin/dakota \
     --workflow execute-release.yml \
     --status success \
     --json headSha,createdAt,displayTitle \
     --limit 10
   ```

   Pick the `headSha` of the run *before* the regression landed.

2. Dispatch the workflow:

   ```bash
   gh workflow run rollback-stable.yml \
     --repo projectbluefin/dakota \
     --ref main \
     -f target_sha=<sha> \
     -f reason="<short reason — appears in audit release notes>" \
     -f include_multiarch=true \
     -f dry_run=true
   ```

3. Read the `verify` job step summary. If digests resolve and cosign verify
   passes, re-dispatch with `dry_run=false` to actually move the tags.

### Defaults that matter

- **`dry_run` defaults to `true`.** Humans must explicitly pass `dry_run=false`
  to live-rollback. This is intentional — a one-button live rollback under
  pressure is exactly when foot-guns fire.
- **`include_multiarch` defaults to `true`.** Leave it on unless ARM is
  intentionally being held back; otherwise `:stable-multiarch` will continue
  to advertise the bad image to `aarch64` users.
- **Concurrency group is `dakota-execute-release`**, identical to the
  promotion workflow. A rollback cannot race with a promotion in flight, and
  vice versa.

### What the workflow guarantees

- `dakota:${target_sha}` and `dakota-nvidia:${target_sha}` both exist (pair
  invariant — refuses to roll back a partial set).
- Both images cosign-verify against the anchored
  `publish.yml@refs/heads/(testing|gh-readonly-queue/testing/.+)` identity.
- Tags are moved with `skopeo copy --preserve-digests --all`, so the digest
  served by `:stable` is exactly the digest cosign signed.
- A GitHub Release (`rollback-<sha>-<unix_ts>`, marked prerelease) is created
  to keep an audit trail of the operator, reason, timestamp, and digests.

### What it does *not* do

- It does **not** rewind the `main` bookmark. `main` continues to point at the
  most recent promoted SHA. The image stream and the git bookmark are
  intentionally decoupled in this flow — if the regression also needs a code
  revert, open a normal PR against `testing` and let the promotion pipeline
  re-promote.
- It does **not** delete the bad image. The previously-stable digest stays in
  GHCR (under its SHA tag) for forensics.
