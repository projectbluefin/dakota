---
name: ci
description: Dakota CI pipeline reference. Covers workflow files, trigger behavior, remote cache architecture, common failures, and promotion flow. Load when debugging CI failures, understanding why a build was or wasn't triggered, or running a manual promotion.
---

# CI Pipeline Operations

Load when debugging CI failures, understanding the build pipeline, or working with the remote CAS cache.

## When NOT to Use

- Diagnosing an individual element build failure → `debugging.md`
- Writing or modifying `.bst` element files → `buildstream.md`
- Understanding what packages flow into the OCI image → `oci-layers.md`

## Quick Reference

| What | Value |
|---|---|
| Workflow file | `.github/workflows/build.yml` |
| Runner | `ubuntu-24.04` (standard GitHub-hosted) |
| Build target | `oci/bluefin.bst` |
| Build timeout | 330 min (job: 360 min) |
| Remote cache server | `cache.projectbluefin.io:11002` |
| Cache auth | mTLS — `CASD_CLIENT_CERT` (repo variable) + `CASD_CLIENT_KEY` (secret) |
| Published image | `ghcr.io/projectbluefin/dakota:{testing,latest,stable}` and `:$SHA` |
| Build logs artifact | `buildstream-logs-x86_64-<variant>` (7-day retention) |
| Trigger (validate) | `pull_request` — `bst show --deps all`, no CAS |
| Trigger (build) | `merge_group`, `schedule` (13:00 UTC), `workflow_dispatch` |
| Nightly schedule rationale | gnome-build-meta nightly finishes ~08:00–11:30 UTC; 13:00 UTC picks up fresh artifacts |

## Workflow Files

| File | Role |
|---|---|
| `.github/workflows/build.yml` | BST build + push artifacts to remote CAS. Fires on merge_group/schedule/dispatch. Does NOT push to GHCR directly. |
| `.github/workflows/publish.yml` | 4-stage pipeline: setup → publish → e2e-gate → promote. Pulls artifact from CAS, exports OCI, pushes `:$sha`, signs, attests, smoke-tests, then promotes to `:testing`. |
| `.github/workflows/release.yml` | Called from `weekly-testing-promotion.yml` after a successful promotion. Creates GitHub Release with card image, SBOM diff, and package changelog. Also available as `workflow_dispatch` for out-of-band cuts. |
| `.github/workflows/weekly-testing-promotion.yml` | Weekly Tuesday promotion (06:00 UTC): 7-day floor check → verify `:testing` digests → cosign verify → e2e → promote to `:latest`+`:stable` → fast-forward branches → call `release.yml`. Has `environment: production` gate requiring human approval. |
| `.github/workflows/e2e.yml` | Smoke test via projectbluefin/testsuite. Fires on PR; `should-run` job skips the test when no image-affecting paths changed. |

## Trigger Behavior

| Behavior | pull_request | merge_group | schedule | workflow_dispatch |
|---|---|---|---|---|
| `validate` job | Yes | No | No | No |
| `e2e` job | Yes (change-detected) | No | No | Yes |
| `build` job | No | Yes | Yes | Yes |
| Push to GHCR? | No | Via publish.yml | Via publish.yml | Via publish.yml |

**PR path:** `validate` + `e2e` (change-detected) — zero remote execution. ~15 min cached, ~30 min cold.

**e2e change detection:** `e2e` uses a `should-run` job that diffs the PR branch against its base. It runs when `elements/`, `files/`, `patches/`, `Justfile`, or `project.conf` change; otherwise the `e2e` job is skipped. Skipped satisfies the required status check.

**Merge queue path:** `build` fires on `merge_group` — full OCI build, real CI gate before merge.

## Remote Cache Architecture

`cache.projectbluefin.io:11002` handles all five BST remote services: artifact cache, source cache, CAS storage, remote execution, and action cache. All use the same endpoint with mTLS auth.

### mTLS Authentication

| Variable | Type | Content |
|---|---|---|
| `CASD_CLIENT_CERT` | Repository **variable** | PEM-encoded client certificate (public) |
| `CASD_CLIENT_KEY` | Repository **secret** | PEM-encoded private key |

**Push is conditional:** Remote cache section is only added to `buildstream-ci.conf` if **both** are set. Without credentials, BST builds from source using local disk cache only — slower but functional. This is normal for external contributors' forks.

## ⚠️ Pre-Commit BST Syntax Gate

For any change to `project.conf`, `*.bst` elements, or `Justfile`:

```bash
just bst show oci/bluefin.bst
```

Must exit clean before `git commit`. Catches invalid option names, types, and element references. Takes 5 seconds. Skipping wastes a 90-second CI build slot.

## ⚠️ Branch Base Rule

Always branch from `upstream/main`, never from local `main`:

```bash
git checkout upstream/main -b feature/my-change
git diff upstream/main...HEAD --stat   # verify before pushing
```

**Recovery when a branch is already dirty:**
```bash
git rebase --onto upstream/main <last-unwanted-commit-sha> <branch-name>
git push --force-with-lease origin <branch-name>
```

## Debugging CI Failures

### Where to Find Logs

| Log | Location |
|---|---|
| Build log | `buildstream-logs` artifact → `logs/` |
| Config generation | "Generate BuildStream CI config" step in workflow |
| Workflow log | GitHub Actions UI → step output |

### Common Failures

| Symptom | Likely cause | Fix |
|---|---|---|
| Build OOM or hangs | Memory pressure with 4 builders | Check element build resource usage |
| "No space left on device" | BST cache fills runner disk | Check if any element generates large buildtrees |
| `bootc container lint` fails | Image structure issues | Check OCI assembly, `/usr/etc` merge |
| Build succeeds locally, fails in CI | Different cached versions | Compare `bst show` output; check remote CAS |
| GHCR push fails | Token permissions | Check `packages: write` permission |
| Remote cache not used | Cert/key not configured | Check repo Variables and Secrets |

### Debugging Workflow

1. **Check config step output** — confirms whether `artifacts:` / `source-caches:` sections are present
2. **Search build log** — look for `[FAILURE]` lines; `on-error: continue` collects all failures
3. **Check if remote cache was hit** — look for `[get artifact]` lines showing `cache.projectbluefin.io:11002`
4. **Reproduce locally** — `just bst build oci/bluefin.bst` uses the same bst2 container

## Generated Files (Pre-Commit Required)

Some files are generated locally and committed — they cannot be regenerated in CI because generation requires `bst artifact list-contents`, which only reads the **local** BST artifact cache (not remote execution cache).

| File | Generator | When to Regenerate |
|---|---|---|
| `files/filemap.json` | `python3 scripts/gen-filemap.py` | After any element change affecting file layout |
| `files/fakecap-manifest.tsv` | `python3 scripts/gen-filemap.py` | Same |

```bash
# Regenerate
rm files/filemap.json files/fakecap-manifest.tsv
python3 scripts/gen-filemap.py
git add files/filemap.json files/fakecap-manifest.tsv
git commit -m "chore: regenerate chunkah filemap and fakecap manifest"
```

Treat these like `Cargo.lock` — commit the updates with your element changes.

## Bot PR CI — GITHUB_TOKEN Suppression

PRs created by a workflow using `GITHUB_TOKEN` do NOT fire `pull_request` events — GitHub suppresses workflow triggers from its own bot token to prevent recursive loops.

**Fix:** Use a GitHub App token (mergeraptor) for `gh pr create` in `track-bst-sources.yml`.

## Ruleset

Ruleset: `main-review-required-with-renovate-bypass`

| Rule | Value |
|---|---|
| Required reviews | 1 approving review |
| Required status checks | `validate` + `e2e` |
| Merge queue | ALLGREEN, max_entries_to_build=1, check_response_timeout=120 min |
| Bypass actors | OrganizationAdmin, Renovate, mergeraptor |

**e2e change detection:** `e2e` only tests PRs touching `elements/`, `files/`, `patches/`, `Justfile`, or `project.conf`. For all other paths (e.g. workflow pin bumps) the `e2e` job is skipped, which satisfies the required check. The `should-run` job uses `git diff` against the PR base — no `paths:` filter on the trigger.

**Critical:** Required status checks must only include checks that fire on `pull_request`. A check that only fires on `merge_group` will permanently block the "Add to merge queue" button.

## Session Bootstrap Rule

At the start of every dakota session, check GNOME OS upstream status:

```bash
gh pr list --repo gnome/gnome-build-meta --state open --limit 10
gh run list --repo projectbluefin/dakota --limit 5
```

## Cross-References

| Skill | When |
|---|---|
| `oci-layers.md` | Understanding what the build produces |
| `debugging.md` | Diagnosing individual element build failures |
| `buildstream.md` | Writing or modifying `.bst` elements |
| `update-refs.md` | Understanding the source tracking workflow |

## Lessons Learned

### publish.yml startup_failure = :testing is stale (2026-06-04)

`startup_failure` on `publish.yml` nightly runs means the BST artifact or
CAS cache lookup failed before the job even started. When this happens on two
or more consecutive nights, `:testing` stops being updated. Symptoms visible
downstream: every dep-update PR shows "SSH never became ready" in e2e because
the QEMU VM tries to boot the stale image. Fix: investigate `publish.yml`
startup_failure first — check repo Secrets/Variables for `CASD_CLIENT_CERT`
and `CASD_CLIENT_KEY` expiry, and confirm the CAS server is reachable.

**Also check if the workflow is disabled.** A `disabled_manually` workflow
silently produces `startup_failure` with zero job output — `jobs: []`.
Check with:

```bash
gh api repos/projectbluefin/dakota/actions/workflows \
  --jq '.workflows[] | "\(.id) \(.state) \(.name)"'
```

Re-enable with:

```bash
gh api repos/projectbluefin/dakota/actions/workflows/<id>/enable --method PUT
```

**Two confirmed causes of `startup_failure` with `jobs: []` (2026-06-04):**

1. **Invalid top-level `permissions:` key** — `artifact-metadata: write` is NOT a
   valid `GITHUB_TOKEN` permission scope. GitHub rejects the workflow at parse time
   before creating any jobs. `actionlint` does not catch this. Remove it.
   Valid scopes: `actions`, `checks`, `contents`, `deployments`, `discussions`,
   `environments`, `id-token`, `issues`, `packages`, `pages`, `pull-requests`,
   `repository-projects`, `security-events`, `statuses`, `attestations`.

2. **Job-level `permissions:` on a reusable workflow call job** — adding a
   `permissions:` block to a job that uses `uses:` (external reusable workflow)
   can cause GitHub to fail the entire workflow at startup. The working pattern
   (used by local `e2e.yml`) is to call the reusable workflow WITHOUT job-level
   permissions; it inherits from the top-level `permissions:` block instead.

**After fixing startup_failure, publish may still fail if no BST artifact is in
CAS for the current main SHA.** This happens when `build.yml` has only run on
branches (not main). Fix: dispatch `build.yml` on main first, wait for it to
complete (~5–6 hours), then dispatch `publish.yml`.

```bash
gh workflow run build.yml --repo projectbluefin/dakota --ref main
# wait for completion, then:
gh workflow run publish.yml --repo projectbluefin/dakota
```

### Dep updates on testing not reaching main (2026-06-04)

When dep-update PRs are merged directly to `testing`, `publish.yml` (which
builds from `main`) never sees them. Before dispatching a build or promotion,
check the gap:

```bash
git log --oneline upstream/main..upstream/testing -- elements/ files/ patches/
```

If commits exist, land them via a PR to `main`:

```bash
git checkout upstream/main -b fix/land-testing-deps
# Apply only element/files/patches diff — avoid docs/CI conflicts:
git diff upstream/main..upstream/testing -- elements/ files/ patches/ \
  > /tmp/testing-deps.patch
git apply --index /tmp/testing-deps.patch
git commit -m "chore(deps): land testing dep updates into main"
git push upstream fix/land-testing-deps
gh pr create --repo projectbluefin/dakota --base main --head fix/land-testing-deps ...
```

Do **not** cherry-pick the squash commits directly — they bundle docs/CI
changes that have already diverged between `testing` and `main`, producing
unresolvable conflicts in `AGENTS.md`, `CODEOWNERS`, and `docs/skills/`.

### Same e2e failure on all PRs = infrastructure, not code (2026-06-04)

If `e2e / GNOME 50 — smoke` fails with identical output across 4+ unrelated
PRs simultaneously, it is always an infrastructure issue — never a per-PR
code bug. The test suite tests `:testing` not the PR branch. Skip individual
PR debugging and go straight to:

```bash
gh run list --repo projectbluefin/dakota --workflow publish.yml --limit 10 \
  --json databaseId,conclusion,createdAt
```

If the last successful publish run is >24 hours old, `:testing` is stale.
Check projectbluefin/testsuite for open issues before filing a new one.

### Remote CAS down = build dies immediately at element loading (2026-06-07)

When `cache.projectbluefin.io:11002` is unreachable, buildbox-casd exits after
6 connection retries (~18 seconds). BST reports this as a cryptic inner failure:

```
BUG: Message handling out of sync, unable to retrieve failure message for element plugins/buildstream-plugins-community.bst
FAILURE Loading elements
error: recipe `bst` failed with exit code 255
```

The real root cause is in the CASD log artifact:

```
[ERROR] Retry limit (5) exceeded for "GetCapabilities()"
[ERROR] 14: Failed to connect to remote host: Connection refused
```

**Diagnosis:**

```bash
gh run download <run-id> --repo projectbluefin/dakota \
  --name buildstream-logs-x86_64-default -D /tmp/bst-logs
cat /tmp/bst-logs/_casd/*.log | grep -E "connect|refused|ERROR" | tail -10
```

**Fix:** The remote CAS is infrastructure — it needs to be restarted on the server.
If the cache is truly down, the build cannot proceed (without the `cache.storage-service`,
BST has no local artifact store and cold-rebuilds everything which times out).
Re-trigger the build once the cache is back up:

```bash
gh workflow run "Build Bluefin dakota" --repo projectbluefin/dakota --ref main
```

**Ghost-local workaround:** Does not apply — ghost's userconfig has no remote CAS
configured, so ghost builds are unaffected by cache outages.

### Ghost-specific build fixes belong in userconfig, NOT elements (2026-06-07)

If a BST element fails to build on ghost but works in CI (remote execution), the
fix must go in ghost's local config — **never in the element itself**. Putting it
in the element invalidates the remote CAS artifact (cache-bust), forcing CI to
rebuild an element it was already handling correctly.

**Wrong:** `elements/bluefin/foo.bst` + `environment: CARGO_PROFILE_RELEASE_LTO: "thin"`
**Right:** ghost `~/.config/buildstream/userconfig.yaml` project/element environment override

Ghost-specific environment overrides can go in userconfig under:
```yaml
projects:
  dakota:
    elements:
      bluefin/uutils-coreutils.bst:
        environment:
          CARGO_PROFILE_RELEASE_LTO: "thin"
```

### Promotion pipeline hardening — bonedigger and release race (2026-06-07)

**bonedigger "workflow file issue":** The lifecycle caller (`bonedigger.yml`) was
pinned to a common SHA that pre-dated `lifecycle.yml` existing in that repo. Also,
the `brand_emoji` input is not declared by the reusable workflow — passing an
undeclared input causes a GitHub workflow validation failure. Fix: update the SHA
pin to a commit where the file exists and remove undeclared inputs.

```bash
# Find commits that contain the target workflow file
gh api "repos/projectbluefin/common/commits?path=.github/workflows/lifecycle.yml&per_page=3" \
  --jq '.[].sha'
```

**release.yml must not re-discover the publish run independently:** If `release.yml`
queries `gh run list --limit 1` after the promotion pipeline completes, a concurrent
publish run for a new SHA can land first and be picked up instead. Always pass the
promoted `source_sha` and `promoted_digest` as `workflow_call` inputs from the
promotion pipeline so `release.yml` filters by exact headSha.

**Invalid OCI digest fallback:** Never synthesize an OCI digest from a git SHA
(`sha256:${git_sha}`). If `skopeo inspect` fails, fail the job — a release with
a fake digest has wrong verification commands in the release notes.

**`cert-identity-regexp` must be fully anchored:** Cosign uses `MatchString` semantics,
so a regexp without a trailing `$` matches any URL with that prefix. Always anchor:
```
^https://github\.com/projectbluefin/dakota/\.github/workflows/publish\.yml@refs/heads/(main|gh-readonly-queue/main/.+)$
```

**SBOM artifact expiry fallback:** Build artifacts expire after 30 days. For
`workflow_dispatch` out-of-band cuts, add a Syft fallback:
```yaml
- name: Download SBOM
  id: sbom_artifact
  continue-on-error: true
  uses: actions/download-artifact@...
- name: Generate SBOM with Syft (fallback)
  if: steps.sbom_artifact.outcome == 'failure'
  run: syft "ghcr.io/.../dakota@${DIGEST}" -o spdx-json=sbom-current/dakota.spdx.json
```


Full pipeline to promote `testing` → `stable` manually:

```bash
# 1. Check for testing-only element commits not yet in main
git fetch upstream
git log --oneline upstream/main..upstream/testing -- elements/ files/ patches/
# If any: land them via PR (see "Dep updates on testing not reaching main" above)

# 2. Ensure publish.yml is enabled
gh api repos/projectbluefin/dakota/actions/workflows \
  --jq '.workflows[] | select(.name | contains("Publish")) | "\(.id) \(.state)"'

# 3. Dispatch publish.yml to build :testing from current main
gh workflow run publish.yml --repo projectbluefin/dakota

# 4. Once publish completes, dispatch promotion (pauses for production environment approval)
gh workflow run weekly-testing-promotion.yml --repo projectbluefin/dakota
```

Step 4 requires approval at: https://github.com/projectbluefin/dakota/deployments

The GitHub release (notes + card + SBOM) is created automatically by
`release.yml` after every successful `publish.yml` run — no manual step needed.
