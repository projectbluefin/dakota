# CI reference

## Jobs

| Job | Triggers | What |
|---|---|---|
| `validate` | `pull_request` | `bst show` — graph + patch check (~15 min) |
| `e2e` | `pull_request` when `elements/`, `files/`, `patches/`, `Justfile`, or `project.conf` changed | Smoke test in QEMU via projectbluefin/testsuite |
| `build` | `merge_group`, `workflow_dispatch`, `schedule` — skips on `pull_request` | Full OCI build (~60–90 min) |
| `build-aarch64` | disabled | ARM64 — pending investigation |

## Publish pipeline (publish.yml)

`build` success on main/testing/next triggers publish.yml via `workflow_run`:

```
build.yml (main|testing|next) → [workflow_run] → publish.yml
                                                  setup → publish-image (matrix) → promote (:testing or :next)
                                                                   └──────────────→ publish-sbom
```

| Job | What |
|---|---|
| `setup` | Resolves SHA, trigger event, and branch |
| `publish-image` | Exports from CAS; runs `chunka@v1` to rechunk; pushes `:$sha`; signs + attests |
| `promote` | `skopeo copy` `:$sha` → `:testing` (merge-queue/schedule/dispatch) |
| `publish-sbom` | Generates SBOM; attaches via oras; signs SBOM (runs in parallel with promote) |

`promote` depends only on `publish-image`, not on SBOM — saves 10–15 min on the critical path.

**`execute-release.yml`** fires on `push: main` and `workflow_dispatch`. A `check-trigger` job reads the commit message — proceeds only when it matches `^ci\(promote\): dakota testing` or `^chore: promote testing to main`. `workflow_dispatch` bypasses the gate. On success: copies `:testing` → `:stable`, then generates a GitHub Release with SBOM diff.

**Critical ordering:** `publish.yml` pulls the OCI artifact from CAS. The artifact is only in CAS if `build.yml` ran first for that SHA. Always dispatch `build.yml --ref testing` (or let push trigger it) before manually dispatching `publish.yml`.

## Stable promotion (execute-release.yml)

Triggered by a push to `main` whose commit message matches the promotion pattern. The normal path is:

```
push to testing (BST-affecting)
  → build.yml → publish.yml → :testing
  → promote-testing-to-main.yml → auto/promote-testing-to-main PR
       → pr-release-gate.yml (cosign verify)
       → auto-merge → push to main (commit: "ci(promote): dakota testing ...")
           → execute-release.yml (check-trigger passes)
               → :testing copied to :stable
               → GitHub Release created
```

Schedule: `promote-testing-to-main.yml` runs `cron: '0 4 * * 2'` (Tuesday 04:00 UTC). That is the only automated promotion cadence.

## Schedule

Builds fire on schedule (13:00 UTC for testing, 03:00 UTC for next), merge_group, or workflow_dispatch.

## Remote cache

`cache.projectbluefin.io:11002` — mTLS via `CASD_CLIENT_CERT` + `CASD_CLIENT_KEY`.

## Published images

`ghcr.io/projectbluefin/dakota:{testing,stable,next,btw}` and `ghcr.io/projectbluefin/dakota:<sha>`

Streams:
- `:testing` — published on every BST-affecting push to `testing` or `main` branch
- `:stable` — promoted from `:testing` via `execute-release.yml` after promotion PR merges to main (Tuesday 04:00 UTC scheduled path, or manual dispatch)

Never bypass the merge queue with `--admin`.

## Manual stable promotion

To manually cut a `:stable` release:

```bash
# 1. Ensure :testing exists and promotion PR is open
gh pr list --repo projectbluefin/dakota --search 'head:auto/promote-testing-to-main state:open'

# 2. If the promotion PR gate has passed, dispatch execute-release directly
gh workflow run execute-release.yml --repo projectbluefin/dakota --ref main

# OR: dispatch promote-testing-to-main to open/update the promotion PR
gh workflow run promote-testing-to-main.yml --repo projectbluefin/dakota
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

## e2e change detection

e2e uses a `should-run` job that diffs `HEAD` against the PR base branch. It fires when any of these paths change:

```
elements/**  files/**  patches/**  Justfile  project.conf
```

There is no `paths:` filter on the `on.pull_request` trigger — the workflow always starts, but the `e2e` job is skipped when `should-run` finds no relevant changes. This means e2e is marked **skipped** (not failed) for action pin bumps and workflow-only changes, which satisfies the required status check.
