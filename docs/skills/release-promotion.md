---
name: release-promotion
description: Dakota publish and promotion flow from testing to stable, including the Mon/Wed/Fri OCI-native execute-release flow, SHA-based freshness check, cosign verify, boot-check gate, and manual recovery. Use when working on execute-release.yml, stable promotion failures, branch bookmark state, or the daily build pipeline.
metadata:
  context7-sources:
    - /websites/github_en_actions
    - /bootc-dev/bootc
---

# Release Promotion

## Overview

Promotion from `testing` to `:stable` is **fully automated on Monday, Wednesday,
and Friday at 18:00 UTC** — no human approval required at any stage.

```text
testing (trunk) → build.yml → publish.yml → :testing tag
                                                  │
                                         Mon/Wed/Fri 18:00 UTC
                                         execute-release.yml schedule
                                         publish-existence guard
                                         SHA freshness → cosign → boot-check
                                                  │
                                         :stable + fast-forward main bookmark
```

`main` is a release bookmark only. It is fast-forwarded by `execute-release.yml` after each successful promotion. Do not open PRs against `main`.

Stable promotion advances all four x86 variants together: `dakota`,
`dakota-nvidia`, `dakota-gaming`, and `dakota-nvidia-gaming`. A missing or
unverified SHA-pinned variant must fail promotion instead of leaving the stable
variant set partially updated.

Do not conflate "publish is healthy" with "stable promotion is healthy".

## When to Use

Use when the task mentions:
- `execute-release.yml`
- stable promotion failures (`:testing` not promoted to `:stable`)
- SHA-based freshness check or scheduled release from `publish.yml`
- `main-bookmark-protection` ruleset
- cosign verify in the release path
- stable release, `:stable`, or scheduled promotion flow
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
3. **`execute-release.yml` runs on a Mon/Wed/Fri schedule after the daily publish.**
   It resolves the current `testing` SHA and verifies that a successful
   `publish.yml` run exists for that exact SHA before resolving the digest. It then
   checks whether the SHA differs from `:stable`; if equal, promotion is skipped.
4. **The schedule is deliberately separate from publish.** `build.yml` and
   `publish.yml` continue their daily cadence, while only the scheduled release
   window promotes a fresh published SHA. This prevents an in-progress or failed
   daily build from becoming stable.
5. **Do not add a promotion PR or merge queue step.** The squash PR ceremony was eliminated
   in the OCI-native redesign (issue 1073). Promotion is a direct OCI tag copy + git
   fast-forward; there is no PR to gate.
6. **For manual recovery, dispatch `execute-release.yml` directly** after verifying the
   `:testing` image is fresh and cosign-verified.

## Promotion Map

```text
push to testing (BST-affecting paths) or daily build schedule
  → build.yml (daily 13:00 UTC schedule)
  → publish.yml (workflow_run)
      → boot-check gate (must boot before :testing is published)
      → :testing tag published to GHCR
  → Mon/Wed/Fri 18:00 UTC execute-release.yml schedule
      → successful publish-existence guard for the current testing SHA
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

`execute-release.yml` runs on the stable-release schedule and keeps manual
dispatch for recovery:

```yaml
on:
  schedule:
    - cron: '0 18 * * 1,3,5'
  workflow_dispatch: {}
```

The first job reads the current `testing` branch SHA, then checks the Actions
API for a successful `publish.yml` run with the same `headSha`. This anchors
digest resolution to a completed publish rather than a floating or still-building
`:testing` tag.

The scheduled path must not substitute a `skopeo inspect` lookup of `:testing`
for the branch SHA or skip the successful-publish check. Manual `promote_sha`
remains the explicit recovery override.

## Hard Rules

- `execute-release.yml` scheduled runs must resolve the current `testing` SHA and find a successful `publish.yml` run with the same `headSha` before promotion.
- `main` is a bookmark only. No PRs target main. `execute-release.yml` is the only writer.
- The `main-bookmark-protection` ruleset must block non-fast-forward and deletion. No merge queue, no required checks.
- The `testing-merge-queue-no-review` ruleset must require `validate` + `e2e` and enable the merge queue.
- Stable promotion cadence is Mon/Wed/Fri at 18:00 UTC — triggered by the scheduled `execute-release.yml` run.
- The SHA freshness check compares the `:testing` SHA with the current `:stable` SHA. Equal → skip. Different → promote.
- cosign `--certificate-identity-regexp` must be anchored with `^...$` and restricted to the publishing workflow file.
- `execute-release.yml` `workflow_dispatch` bypass is allowed for manual recovery only.
- `skip_release_gate` defaults to `false`; use it only when the exact candidate
  images are already published and the testsuite cannot exercise a variant
  (for example, an Nvidia image on a runner without an Nvidia device). The
  post-release digest verification remains mandatory.

## Manual Recovery Shortcuts

```bash
# check recent execute-release runs
gh run list --repo projectbluefin/dakota --workflow 'Execute Release' --limit 10

# check recent publish runs before the next scheduled release
gh run list --repo projectbluefin/dakota --workflow 'Publish Bluefin dakota' --limit 10

# dispatch execute-release manually (use only for recovery)
gh workflow run execute-release.yml --repo projectbluefin/dakota --ref testing

# emergency recovery when testsuite cannot boot a variant-specific image
gh workflow run execute-release.yml --repo projectbluefin/dakota --ref testing \
  -f skip_release_gate=true

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

|                                          Rationalization |                                                                                                        Reality |
| -------------------------------------------------------: | -------------------------------------------------------------------------------------------------------------: |
|          "execute-release failed, so publish is broken." |                                            Different layer. Publish may be healthy while promotion is blocked. |
|     "Let's use the floating :testing tag as the anchor." | TOCTOU race. Use the current `testing` ref and require a successful `publish.yml` run with the same `headSha`. |
|         "main has diverged — let's open a PR to fix it." |                                  main is a bookmark. Only `execute-release.yml` writes to it via fast-forward. |
|               "The freshness check is too conservative." |                                         Equal SHAs mean `:stable` is already current. Promotion is not needed. |
| "This reusable caller only needs job-level permissions." |                                Wrong often enough to deserve a scar. Check top-level caller permissions first. |

## Red Flags

- `execute-release.yml` using `skopeo inspect :testing` to get the SHA instead of the current `testing` ref plus a matching successful publish run
- Any PR targeting `main` (main is a bookmark, not a development branch)
- Adding a merge queue or required checks to the `main-bookmark-protection` ruleset
- `testing-merge-queue-no-review` ruleset missing `validate` or `e2e` required checks
- Editing stable-promotion logic while the real failure is earlier in publish plumbing

## Verification

- [ ] `execute-release.yml` schedules Mon/Wed/Fri at `0 18 * * 1,3,5`
- [ ] Scheduled promotion verifies a successful `publish.yml` run for the exact current `testing` SHA
- [ ] Manual `workflow_dispatch` recovery inputs remain available
- [ ] `main-bookmark-protection` ruleset: non_fast_forward + deletion blocked, no merge queue
- [ ] `testing-merge-queue-no-review` ruleset: `validate` + `e2e` required, merge queue enabled
- [ ] No PRs exist targeting `main`
- [ ] `testing` is the GitHub default branch
- [ ] Stable promoted without any human interaction after a successful publish

## Lessons Learned

### release/blocked after CI-only push to testing is expected

When a paths-ignored push (e.g. `.github/workflows/**` change) advances the `testing`
HEAD, the next scheduled release finds no successful publish run for the new SHA.
The release correctly skips — the SHA has never been built and published.

This is not a pipeline failure. The resolution is automatic:
1. The BST build for the prior SHA completes.
2. `publish.yml` fires → `:testing` updated.
3. The next Mon/Wed/Fri release window re-evaluates the current SHA.

### One BST build at a time — cancel everything before starting a new build

Before triggering or landing any change that starts a new BST build, cancel ALL
in-progress BST jobs.

```bash
gh run list --repo projectbluefin/dakota --json databaseId,status,name \
  | python3 -c "import json,sys; [print(r['databaseId'], r['name']) for r in json.load(sys.stdin) if r['status'] in ('in_progress','queued','pending')]"
gh run cancel <run-id> --repo projectbluefin/dakota
```

Cancel everything, let one build finish, then re-trigger if needed.

### promote_sha recovery — when testing advances past the build SHA (2026-07-28)

Pushing workflow-only fixes to `testing` (which is the default branch) advances the
testing HEAD without a corresponding publish run. The next scheduled
`execute-release` sees no successful publish for the current SHA and skips promotion.

**Recovery:** Use the `promote_sha` workflow_dispatch input:
```bash
gh workflow run execute-release.yml \
  --repo projectbluefin/dakota \
  --ref testing \
  -f promote_sha=<the-build-sha>
```

This bypasses the scheduled publish-existence guard and promotes the specific build
SHA even though testing has advanced. Only use it after confirming that the
SHA-tagged images exist and were cosign-signed.

**Prerequisite:** The images at `promote_sha` must be cosign-signed. If publish
failed before signing (e.g. due to the `--creds` skopeo issue), you MUST wait for
a successful re-publish before dispatching execute-release.

### main/testing bookmark divergence — commits directly on main (2026-07-28)

If commits land directly on `main` (bypassing testing→promotion), `main` diverges
from `testing`. The reusable execute-release action uses `force=false` for the
main fast-forward, which fails with HTTP 422 for diverged branches.

**Detection:**
```bash
gh api repos/projectbluefin/dakota/compare/TESTING_SHA...main --jq '.status'
# returns "diverged" instead of "behind" (which is normal)
```

**Fix in execute-release.yml:** Remove `fast_forward_branch` from the reusable action
call; add a separate `update-main-bookmark` job with `force=true` that runs after
execute. This handles both the normal (behind) and diverged cases:
```yaml
update-main-bookmark:
  needs: [freshness-check, execute]
  if: always() && needs.execute.result == 'success'
  runs-on: ubuntu-latest
  permissions:
    contents: write
  env:
    GH_TOKEN: ${{ github.token }}
  steps:
    - name: Force-update main to promoted SHA
      env:
        TARGET_SHA: ${{ needs.freshness-check.outputs.build_sha }}
      run: |
        compare=$(gh api "repos/${{ github.repository }}/compare/${TARGET_SHA}...main" \
          --jq '.status' 2>/dev/null || echo "unknown")
        [ "$compare" = 'identical' ] && exit 0
        gh api "repos/${{ github.repository }}/git/refs/heads/main" \
          --method PATCH --field sha="$TARGET_SHA" --field force=true
```

### OCI-native promotion model history (2026-06-23)

Dakota migrated from a weekly squash-PR ceremony to an OCI-native promotion
flow (issue 1073). The original rollout was daily; the current release cadence
is documented above. The key differences were:

- **Deleted workflows:** `promote-testing-to-main.yml`, `pr-release-gate.yml`,
  `sync-main-to-testing.yml`, `cache-warm.yml`.
- **`execute-release.yml`** replaced the promotion PR ceremony. Its historical
  `workflow_run` trigger has since been replaced by the Mon/Wed/Fri schedule.
- **SHA anchor:** the current branch SHA plus a matching successful `publish.yml`
  run is the source of truth for scheduled releases. Never use `skopeo inspect
  :testing` as the SHA anchor — that is a TOCTOU race.
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

### Scheduled release must match a published SHA (2026-08-09)

The daily build and publish cadence is intentionally independent from the
Mon/Wed/Fri stable cadence. A scheduled `execute-release.yml` run must locate a
successful `publish.yml` run whose `headSha` equals the current `testing` ref
before resolving the digest. The digest action can fall back to a SHA tag, but
that fallback alone does not prove the SHA passed publish and boot-check.

### Keep stable variant lists aligned

The stable x86 set is `dakota`, `dakota-nvidia`, `dakota-gaming`, and
`dakota-nvidia-gaming`. When adding or removing an image variant, update the
reusable release matrix, release-note digest collection and table, post-release
digest verification, and untagged package cleanup together. The release
workflow can otherwise promote only part of the variant set or report success
without verifying the new image.

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
