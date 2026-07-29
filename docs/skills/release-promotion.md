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
                               :<FSDK_MINOR>-stable + :stable + fast-forward main bookmark
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
   - skopeo copy `:testing` → `:<FSDK_MINOR>-stable` + `:stable`
   - fast-forward `main` bookmark
3. **`execute-release.yml` fires via `workflow_run` from `publish.yml` on the `testing` branch.**
   It checks whether the SHA published as `:testing` differs from the current `:stable`. If
   they are equal, promotion is skipped (already up to date). If they differ, cosign verify
   runs, then the copy to `:<FSDK_MINOR>-stable` plus `:stable`, and the fast-forward.
   The image is already boot-checked by `publish.yml`.
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
          → skopeo copy :testing → :<FSDK_MINOR>-stable + :stable
          → fast-forward main bookmark
          → create GitHub Release
```

## Tag contract, permissions, and credentials

- `publish.yml` on `testing` publishes immutable `:<sha>` and `:<FSDK_VERSION>`
  tags, then moves `:testing` and `:<FSDK_MINOR>-testing`.
- `publish.yml` on `next` publishes the same immutable evidence tags, then moves
  `:next` / `:<FSDK_MINOR>-next` and `:btw` / `:<FSDK_MINOR>-btw` together.
  `:btw` must always resolve to the same digest as `:next`.
- `execute-release.yml` promotes the tested `testing` digest to both
  `:<FSDK_MINOR>-stable` and `:stable`, then fast-forwards `main`.
- `main` is a bookmark only. It never builds independently and it never owns a
  separate image lineage from `testing`.

Publishing and promotion need the top-level GitHub Actions permissions below:

```yaml
permissions:
  contents: write
  packages: write
  attestations: write
  id-token: write
```

- `packages: write` pushes GHCR tags.
- `attestations: write` uploads GitHub artifact attestations.
- `id-token: write` enables keyless cosign signing and verification.
- `contents: write` updates release notes and the `main` bookmark.

Build and publish jobs on `testing` / `next` also require BuildBarn cache
credentials:
- `CASD_CLIENT_CERT` — repository variable containing the PEM client cert
- `CASD_CLIENT_KEY` — repository secret containing the PEM client key

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
- `skip_release_gate` defaults to `false`; use it only when the exact candidate
  images are already published and the testsuite cannot exercise a variant
  (for example, an Nvidia image on a runner without an Nvidia device). The
  post-release digest verification remains mandatory.

## Manual Recovery Shortcuts

```bash
# check recent execute-release runs
gh run list --repo projectbluefin/dakota --workflow 'Execute Release' --limit 10

# check recent publish runs (execute-release fires after these)
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
- [ ] Publish and ARM export jobs verify FSDK OCI labels before chunking or pushing

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

### Stable release must move the versioned tag and alias together (2026-07-29)

`execute-release.yml` cannot stop after promoting `:<FSDK_MINOR>-stable`.
That channel tag comes from the pinned freedesktop-sdk junction ref, not from a
separate Dakota version number. The stable alias has to move in the same release path, and any failure while
syncing `:stable` must restore both destinations to their pre-release digests.

Apply the same rule to `rollback-stable.yml`: move `:<FSDK_MINOR>-stable` and
`:stable` as a pair for every supported stable variant (`dakota`,
`dakota-nvidia`, `dakota-gaming`), then verify both tags point at the expected
digest before declaring rollback complete.

### Snapshot stable destinations independently and reconcile partial promotion (2026-07-29)

Do not restore `:${FSDK_MINOR}-stable` from the previous `:stable` digest.
Snapshot the versioned tag and the `:stable` alias independently for every
supported variant before moving anything, then restore each destination from
its own snapshot if a rollback path is needed.

`reusable-execute-release.yml` is intentionally best-effort: it can leave some
variants already promoted to `:${FSDK_MINOR}-stable` while returning failure for
the overall job. The caller must reconcile `:stable` for the promoted subset
before failing the workflow, otherwise the versioned stable tag and the stable
alias drift apart for those variants.

Treat `dakota` as required and the `continue-on-error` stable variants
(`dakota-nvidia`, `dakota-gaming`) as optional only for recovery planning.
If an optional SHA tag is absent, keep reconciling the variants whose digests
are known instead of aborting the whole repair loop first.

If any alias move or rollback move fails mid-loop, restore the entire
snapshotted stable set (`:${FSDK_MINOR}-stable` and `:stable` for every
supported variant), not just the variant that failed. Per-variant restore
logic leaves earlier variants split when a later move fails.

### Optional stable source resolution must retry before skipping (2026-07-29)

The digest resolver that prepares `source_digests` for stable-tag repair
cannot treat every `skopeo inspect` failure as "optional variant absent".
Retry inspect failures first, and only skip an optional variant when the
final failure is a classified manifest-absence response (for GHCR, exit
status `2` plus `manifest unknown` / `name unknown` in the error text).

Any other registry/auth/TLS failure must stop `execute-release.yml` before
promotion/reconciliation proceeds. Otherwise the reusable release can still
promote `:${FSDK_MINOR}-stable` for that variant while the caller lacks the
expected digest needed to reconcile `:stable`, leaving the tag pair split.

### promote_sha recovery — when testing advances past the build SHA (2026-07-28)

Pushing workflow-only fixes to `testing` (which is the default branch) advances the
testing HEAD past the build SHA. The auto-triggered execute-release sees
`CURRENT_SHA != BUILD_SHA` and skips promotion ("testing has advanced — will promote
next build").

**Recovery:** Use the `promote_sha` workflow_dispatch input:
```bash
gh workflow run execute-release.yml \
  --repo projectbluefin/dakota \
  --ref testing \
  -f promote_sha=<the-build-sha>
```

This bypasses the SHA mismatch guard and promotes the specific build SHA even though
testing has advanced. Only the SHA-tagged images need to exist in GHCR (they do —
push succeeds before the verify step runs even in failed publish runs).

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
  runs-on: ubuntu-24.04
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

### Keep stable variant lists aligned

When adding an image variant to stable promotion, update the reusable release
matrix, release-note digest collection, post-release digest verification, and
untagged package cleanup together. The release workflow can otherwise promote
only part of the variant set or report success without verifying the new image.

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

- `dakota:${target_sha}`, `dakota-nvidia:${target_sha}`, and
  `dakota-gaming:${target_sha}` all exist; stable rollback treats the default,
  Nvidia, and gaming images as one supported stable set and refuses a partial
  rollback.
- All three images cosign-verify against the anchored
  `publish.yml@refs/heads/(testing|gh-readonly-queue/testing/.+)` identity.
- Tags are moved with `skopeo copy --preserve-digests --all`, so the digests
  served by `:<FSDK_MINOR>-stable` and `:stable` are exactly the digests cosign
  signed.
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
