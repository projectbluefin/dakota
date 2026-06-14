# CI reference

## Jobs

| Job | Triggers | What |
|---|---|---|
| `validate` | `pull_request` | `bst show` — graph + patch check (~15 min) |
| `e2e` | `pull_request` when `elements/`, `files/`, `patches/`, `Justfile`, or `project.conf` changed | Smoke test in QEMU via projectbluefin/testsuite |
| `build` | `merge_group`, `schedule`, `workflow_dispatch` (skips on `pull_request`) | Full OCI build (~60–90 min) |
| `build-aarch64` | disabled | ARM64 — pending investigation |

## Publish pipeline (publish.yml)

`build` success on main/testing/next triggers publish.yml via `workflow_run`:

```
build.yml (main) → [workflow_run] → publish.yml
                                    setup → publish-image (matrix) → promote
                                                     └──────────────→ publish-sbom
```

| Job | What |
|---|---|
| `setup` | Resolves SHA, trigger event, and branch |
| `publish-image` | Exports from CAS; runs `chunka@v1` to rechunk; pushes `:$sha`; signs + attests |
| `promote` | `skopeo copy` `:$sha` → `:testing` (merge-queue/schedule/dispatch) |
| `publish-sbom` | Generates SBOM; attaches via oras; signs SBOM (runs in parallel with promote) |

`promote` depends only on `publish-image`, not on SBOM — saves 10–15 min on the critical path.

After every successful publish, `execute-release.yml` auto-fires and creates a GitHub Release.

After every successful publish, `release.yml` auto-fires (via `workflow_run`) and creates a GitHub Release with a card image, SBOM diff, and package changelog.

**Critical ordering:** `publish.yml` pulls the OCI artifact from CAS. The artifact
is only in CAS if `build.yml` ran on `main` first. If `build.yml` has only run on
feature branches, CAS will not have the artifact for main's SHA and publish will
fail with `"No artifacts to stage"`. Always dispatch `build.yml --ref main` before
manually dispatching `publish.yml`.

## Weekly promotion (weekly-testing-promotion.yml)

Runs **Sunday 06:00 UTC**. Promotes `:testing` → `:latest` + `:stable` via digest-pinned re-tagging, then fast-forwards the `latest` and `stable` git branches to the promoted source SHA.

```
resolve → check-diff → promote → update-branches
```

| Job | What |
|---|---|
| `resolve` | Pins `:testing` digest, verifies default + NVIDIA share same source SHA |
| `check-diff` | Skips if `:testing` == `:latest` (nothing new to promote) |
| `promote` | Re-tags both variants as `:latest` + `:stable` (requires `production` environment approval) |
| `update-branches` | Fast-forwards `latest` and `stable` branches to promoted source SHA |

## Schedule

**13:00 UTC** daily — runs after GBM nightly (~08:00 UTC finish).

## Remote cache

`cache.projectbluefin.io:11002` — mTLS via `CASD_CLIENT_CERT` + `CASD_CLIENT_KEY`.

## Published images

`ghcr.io/projectbluefin/dakota:{testing,latest,stable}` and `ghcr.io/projectbluefin/dakota:<sha>`

Streams:
- `:testing` — nightly build, promoted after e2e passes
- `:latest` — weekly promotion from testing (Tuesday 06:00 UTC)
- `:stable` — weekly promotion from testing (same cadence as latest)

Build triggers: `merge_group`, `schedule`, `workflow_dispatch` — **not** `pull_request`.

Never bypass the merge queue with `--admin`.

## Manual stable promotion

To manually cut a `:stable` and `:latest` release:

```bash
# 1. Ensure :testing exists and is healthy
gh run list --repo projectbluefin/dakota --workflow "Publish Bluefin dakota" --limit 5

# 2. Dispatch the weekly promotion workflow
gh workflow run weekly-testing-promotion.yml \
  --repo projectbluefin/dakota

# 3. Approve the deployment at the production environment gate
# Approval URL: https://github.com/projectbluefin/dakota/deployments
```

The `promote` job requires approval via the `production` GitHub Environment before it runs. The number of required approvals is configured in the environment settings.

## Restarting the factory (publish pipeline has been idle)

When the publish pipeline has been paused intentionally (e.g., post-refactor),
the restart sequence is:

```bash
# 1. Verify publish.yml is healthy — no startup_failure
gh run list --repo projectbluefin/dakota --workflow publish.yml --limit 5

# 2. Dispatch a fresh build on main to populate the CAS
gh workflow run build.yml --repo projectbluefin/dakota --ref main
# Wait ~60–90 minutes for build to complete

# 3. Dispatch publish.yml after build finishes (or let workflow_run auto-trigger)
gh workflow run publish.yml --repo projectbluefin/dakota --ref main

# 4. Monitor until :testing lands
gh run watch --repo projectbluefin/dakota

# 5. Cut stable release (see Manual stable promotion above)
```

**Common failure: `startup_failure` with `jobs: []`**

This means GitHub rejected the workflow YAML before creating any jobs — no logs
are available. Root causes found in this repo:

| Cause | Fix |
|---|---|
| `artifact-metadata: write` in `permissions:` block | Not a valid GITHUB_TOKEN scope; remove it |
| Job-level `permissions:` on a reusable workflow call job | Remove the job-level block; let it inherit from top-level |

Valid `GITHUB_TOKEN` permission scopes: `actions`, `attestations`, `checks`,
`contents`, `deployments`, `discussions`, `environments`, `id-token`, `issues`,
`packages`, `pages`, `pull-requests`, `repository-projects`, `security-events`,
`statuses`. Any unknown scope causes `startup_failure`.

## e2e change detection

e2e uses a `should-run` job that diffs `HEAD` against the PR base branch. It fires when any of these paths change:

```
elements/**  files/**  patches/**  Justfile  project.conf
```

There is no `paths:` filter on the `on.pull_request` trigger — the workflow always starts, but the `e2e` job is skipped when `should-run` finds no relevant changes. This means e2e is marked **skipped** (not failed) for action pin bumps and workflow-only changes, which satisfies the required status check.
