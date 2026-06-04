# CI reference

## Jobs

| Job | Triggers | What |
|---|---|---|
| `validate` | `pull_request` | `bst show` — graph + patch check (~5 min) |
| `e2e` | `pull_request` (path-filtered) | Smoke test in QEMU via projectbluefin/testsuite |
| `build` | `merge_group`, `schedule`, `workflow_dispatch` | Full OCI build (~60–90 min) |
| `build-aarch64` | disabled | ARM64 — pending investigation |

## Publish pipeline (publish.yml)

`build` success on main triggers publish.yml via `workflow_run`:

```
build.yml (main) → [workflow_run] → publish.yml
                                    setup → publish (matrix) → e2e-gate → promote
```

| Job | What |
|---|---|
| `setup` | Resolves SHA and trigger event |
| `publish` | Exports from CAS, pushes `:$sha`, signs, SBOM, attests |
| `e2e-gate` | Smoke-tests `ghcr.io/projectbluefin/dakota:$sha` — schedule/dispatch only |
| `promote` | Re-tags `:$sha` → `:testing` after e2e passes — schedule/dispatch only |

`:testing` is never published without a passing e2e smoke test.

**Critical ordering:** `publish.yml` pulls the OCI artifact from CAS. The artifact
is only in CAS if `build.yml` ran on `main` first. If `build.yml` has only run on
feature branches, CAS will not have the artifact for main's SHA and publish will
fail with `"No artifacts to stage"`. Always dispatch `build.yml --ref main` before
manually dispatching `publish.yml`.

## Weekly promotion (weekly-testing-promotion.yml)

Runs Tuesday 06:00 UTC. Promotes `:testing` → `:latest` + `:stable` via digest-pinned re-tagging.

```
resolve → check-diff → promote → update-branches
```

| Job | What |
|---|---|
| `resolve` | Pins `:testing` digest, verifies default + NVIDIA share same source SHA |
| `check-diff` | Skips if `:testing` == `:latest` (nothing new to promote) |
| `promote` | Re-tags both variants as `:latest` + `:stable` |
| `update-branches` | Fast-forwards `latest` and `stable` branches to promoted SHA |

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
gh run list --repo projectbluefin/dakota --workflow publish.yml --limit 5

# 2. Dispatch the weekly promotion workflow
gh workflow run weekly-testing-promotion.yml \
  --repo projectbluefin/dakota

# 3. Two human approvals required via production environment gate
# Approval URL: https://github.com/projectbluefin/dakota/deployments
```

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

## e2e path filter

e2e only fires when these paths change:

```
elements/**  files/**  patches/**  Justfile  project.conf
```

PRs touching only `.github/workflows/` (action pins, bst2 bumps) skip e2e — the check is marked skipped, which satisfies the required status check. Junction bumps in `elements/` always run e2e.
