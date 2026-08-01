# CI reference

## Jobs

| Job | Triggers | What |
|---|---|---|
| `validate` | `pull_request` | `bst show` — graph + patch check (~15 min) |
| `e2e` | `pull_request` when `elements/`, `files/`, `patches/`, `Justfile`, or `project.conf` changed | Smoke test in QEMU via projectbluefin/testsuite |
| `build` | `push: testing/next` (paths-ignore: `.github/workflows/**`, `docs/**`, `**.md`, `AGENTS.md`), `merge_group`, `workflow_dispatch`, `schedule: daily 13:00 UTC` — skips on `pull_request` | Full OCI build (~60–90 min) |
| `build-aarch64` | `push: testing/main` (BST-affecting paths only), `workflow_run` from `publish.yml` on `testing`, `workflow_dispatch` | ARM64 — fully decoupled, never blocks release |

## Publish pipeline (publish.yml)

`build` success on `testing` or `next` triggers `publish.yml` via `workflow_run`:

```
build.yml (testing|next) → [workflow_run] → publish.yml
                                             setup → publish-image → boot-check → promote (:testing or :next)
                                                                  └──────────→ publish-sbom (parallel)
```

| Job | What |
|---|---|
| `setup` | Resolves SHA, trigger event, and branch |
| `publish-image` | Exports from CAS; runs `chunka@v1` to rechunk; pushes `:$sha`; signs + attests |
| `boot-check` | Hard gate — image must boot before `:testing` is promoted |
| `promote` | `skopeo copy` `:$sha` → `:testing` (only runs after boot-check passes) |
| `publish-sbom` | Generates SBOM; attaches via oras; signs SBOM (runs in parallel with promote) |

`promote` depends only on `publish-image` + `boot-check`, not on SBOM — saves 10–15 min on the critical path.

**Critical ordering:** `publish.yml` pulls the OCI artifact from CAS. The artifact is only in CAS if `build.yml` ran first for that SHA. Always dispatch `build.yml --ref testing` (or let push trigger it) before manually dispatching `publish.yml`.

## Stable promotion (execute-release.yml)

`execute-release.yml` fires via `workflow_run` from `publish.yml` on the `testing` branch — no commit message gate, no PR, no human approval.

```
push to testing (BST-affecting) or daily 13:00 UTC schedule
  → build.yml → publish.yml → boot-check → :testing
  → execute-release.yml (workflow_run from publish on testing)
       → SHA freshness check (:testing SHA vs :stable SHA)
           → skip if equal (already up to date)
           → cosign verify :testing
           → skopeo copy :testing → :stable
           → fast-forward main bookmark
           → GitHub Release created
```

`main` is a **release bookmark only** — fast-forwarded by `execute-release.yml` after each successful promotion. Do not open PRs against `main`.

## Schedule

Build fires daily at 13:00 UTC (`schedule:` in `build.yml`), plus on every BST-affecting push to `testing` or `next`, `merge_group`, and `workflow_dispatch`.

## Remote execution and cache

`cache.projectbluefin.io:11002` — BuildBox 1.4.11 execution, remote CAS, artifact/source caches, and action cache behind mTLS via `CASD_CLIENT_CERT` + `CASD_CLIENT_KEY`. Build jobs fail closed; publish uses a fetch-only configuration so it can materialize images locally.

## Published images

`ghcr.io/projectbluefin/dakota:{testing,stable,next,btw}` and `ghcr.io/projectbluefin/dakota:<sha>`

Streams:
- `:testing` — published on every BST-affecting push to the `testing` branch (or daily schedule)
- `:stable` — promoted from `:testing` daily by `execute-release.yml` (when `:testing` SHA differs from `:stable`)
- `:next` / `:btw` — published from the `next` branch; never promoted to `:stable`

Never bypass the merge queue with `--admin`.

## Manual stable promotion

To manually cut a `:stable` release:

```bash
# 1. Verify :testing is fresh and cosign-verified, then dispatch execute-release directly
gh workflow run execute-release.yml --repo projectbluefin/dakota --ref testing
```

## Restarting the factory (publish pipeline has been idle)

When the publish pipeline has been paused intentionally (e.g., post-refactor),
the restart sequence is:

```bash
# 1. Verify publish.yml is healthy — no startup_failure
gh run list --repo projectbluefin/dakota --workflow publish.yml --limit 5

# 2. Dispatch a fresh build on testing to populate the CAS
gh workflow run build.yml --repo projectbluefin/dakota --ref testing
# Wait ~60–90 minutes for build to complete

# 3. publish.yml auto-triggers via workflow_run; if not, dispatch manually
gh workflow run publish.yml --repo projectbluefin/dakota --ref testing

# 4. Monitor until :testing lands, then execute-release auto-triggers
gh run watch --repo projectbluefin/dakota
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
