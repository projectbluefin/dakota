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
| Trigger (build) | `merge_group`, `workflow_dispatch` (no daily schedule) |
**Nightly schedule rationale** — no longer applicable; schedule trigger was removed in favour of continuous builds on every merge.

**Merge queue path:** `build` fires on `merge_group` — full OCI build, real CI gate before merge. On success, `publish.yml` immediately promotes the new image to `:testing`.

## Workflow Files

| File | Role |
|---|---|
| `.github/workflows/build.yml` | BST build + push artifacts to remote CAS. Fires on `merge_group` and `workflow_dispatch` only (no schedule). Does NOT push to GHCR directly. |
| `.github/workflows/publish.yml` | 3-stage pipeline: setup → publish → promote. Pulls artifact from CAS, exports OCI, pushes `:$sha`, signs, attests, then immediately promotes to `:testing` on every successful merge. No e2e gate — that lives only in the weekly promotion. |
| `.github/workflows/promote-testing-to-main.yml` | Thin caller for `reusable-promote.yml` in `projectbluefin/actions`. Fires on `push: testing`, nightly schedule (23:00 UTC), and `workflow_dispatch`. Opens or updates the promotion PR that gates `:testing` → `:stable`. |
| `.github/workflows/execute-release.yml` | Fires on `push: main` + `workflow_dispatch`. A `check-trigger` job reads the squash-merge commit message — only proceeds when it starts with `ci: promote testing images to stable`. Calls `reusable-execute-release.yml` (copies image tags) then `reusable-release.yml` (generates GitHub Release + SBOM diff). |
| `.github/workflows/e2e.yml` | Smoke test via projectbluefin/testsuite. Fires on PR; `should-run` job skips the test when no image-affecting paths changed. |
| `.github/workflows/vulnerability-scan.yml` | Weekly Monday 08:00 UTC CVE scan via `reusable-vulnerability-scan.yml`. Also available as `workflow_dispatch` with optional `image_ref` input. Results surface in the GitHub Security tab. |

## Trigger Behavior

| Behavior | pull_request | merge_group | workflow_dispatch | schedule |
|---|---|---|---|---|
| `validate` job | Yes | No | No | No |
| `e2e` job | Yes (change-detected) | No | Yes | No |
| `build` job | No | Yes | Yes | No |
| `cache-warm` job | No | No | Yes | Yes (Mon/Thu 06:00 UTC) |
| Push to GHCR? | No | Via publish.yml | Via publish.yml | No |

**PR path:** `validate` + `e2e` (change-detected) — zero remote execution. ~15 min cached, ~30 min cold.

**e2e change detection:** `e2e` uses a `should-run` job that diffs the PR branch against its base. It runs when `elements/`, `files/`, `patches/`, `Justfile`, or `project.conf` change; otherwise the `e2e` job is skipped. Skipped satisfies the required status check.

**Merge queue path:** `build` fires on `merge_group` — full OCI build, real CI gate before merge.

**Cache-warm path:** `cache-warm.yml` runs Monday and Thursday at 06:00 UTC and on manual dispatch. Builds the default variant against the remote CAS so merge-queue builds land on cache hits even after junction ref bumps or upstream `gnome-build-meta` rebuilds. Failures are non-blocking — the warm build is best-effort. Addresses the cold-start non-determinism documented in [common automation-audit ND1](https://github.com/projectbluefin/common/blob/main/docs/factory/automation-audit/non-deterministic-steps.md).

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

### crun 1.21 (resolute) breaks just sbom on GHA — use --runtime runc (2026-06-08)

`update-podman: true` in `setup-runner` installs crun 1.21 from Ubuntu 26.04
(resolute). This version has two new failure modes that break `just sbom` on
GHA runners:

1. **seccomp BPF linkat EPERM** — crun caches compiled seccomp BPF programs
   via `linkat()`. The GHA runner kernel's `fs.protected_hardlinks` or user-
   namespace restrictions block the hard-link from `.cache/seccomp/` to the
   container bundle path:
   ```
   crun: linkat `.cache/seccomp/<hash>` to `<container-id>/seccomp.bpf`: Permission denied
   ```

2. **systemd probe EACCES** — crun probes systemd presence and caches the result
   in `$XDG_RUNTIME_DIR/crun/.cache/systemd-missing-properties`. On GHA the
   runtime dir is either uninitialised or was created by root in a prior privileged
   step, causing user 1001 to get EACCES:
   ```
   crun: opendir `/run/user/1001/crun/.cache/systemd-missing-properties`: Permission denied
   ```

**Fix:** add `--runtime runc` to both `podman run` calls in `just sbom`. runc is
always available on ubuntu-24.04 GHA runners (Docker installs it). runc has
neither the seccomp BPF caching nor the systemd probing.

**Wrong partial fixes (both insufficient alone):**
- Dropping `--privileged` (#745) — doesn't prevent either error
- Adding `--security-opt seccomp=unconfined` (#747) — fixes error 1 but not error 2

**Do not** add `seccomp=unconfined` as a workaround; use `--runtime runc` instead.
`bst show` and `buildstream-sbom` are read-only BST operations; runc is fully
sufficient.

```justfile
# ✅ correct
podman run --rm --network=host --runtime runc ...

# ❌ wrong — triggers crun 1.21 failure modes
podman run --rm --network=host ...
podman run --rm --network=host --security-opt seccomp=unconfined ...
```

### Continuous :testing model — every merge ships immediately (2026-06-07)

The pipeline was redesigned so every PR merge produces a new `:testing` image
without any e2e gate in the publish path. The schedule trigger was removed from
`build.yml`; builds now only fire on `merge_group` and `workflow_dispatch`.

**New flow:**
```
PR merge_group → build.yml → publish.yml → :$sha → :testing  (no e2e)
                                                           │
                     weekly-testing-promotion.yml ─────────┘
                     (e2e gate here, then :stable)
```

**Implication:** `:testing` may briefly be broken if a PR introduces a regression.
The e2e gate at the weekly promotion prevents regressions from reaching `:stable`.

**If :testing breaks:** look at the last few merge SHAs and bisect with
`gh run list --workflow "Publish Bluefin dakota" --limit 10`.

**TOCTOU guard interaction:** the weekly promotion's lock-sha step uses a GitHub
compare API ancestor check rather than exact equality. With continuous builds,
main will often be 1–2 commits ahead of `:testing` by Tuesday 06:00 UTC. An
exact-equality check would cause every promotion to fail. The ancestor check
allows promotion as long as `:testing` is a valid ancestor of main (i.e.,
histories have not diverged):

```bash
COMPARE=$(gh api "repos/${REPO}/compare/${SOURCE_SHA}...${CURRENT_SHA}" --jq '.status')
# "ahead" = main advanced past :testing = normal and fine
# anything else = diverged = abort
```

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

**Real example (2026-06-07):** Adding `CARGO_PROFILE_RELEASE_LTO: "thin"` to
`uutils-coreutils.bst` to fix a SIGABRT on ghost caused a 626-element cold rebuild
in CI. The build ran for 5h31m and timed out without completing (330-minute limit).

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

### Diagnosing a slow in-progress build via GitHub API (2026-06-07)

When a build has been running for 2–3+ hours and you want to know what's being
compiled without waiting for a timeout:

```bash
# 1. Find the in-progress build and its job IDs
gh api repos/projectbluefin/dakota/actions/runs/<run-id>/jobs | python3 -c "
import json, sys
from datetime import datetime, timezone
d = json.load(sys.stdin)
now = datetime.now(timezone.utc)
for job in d.get('jobs', []):
    if job.get('started_at'):
        s = datetime.fromisoformat(job['started_at'].replace('Z','+00:00'))
        mins = int((now - s).total_seconds() / 60)
        print(f\"{job['id']} | {job['status']} | {mins}m | {job['name'][:60]}\")
"

# 2. Fetch the live log (note: truncated at ~23K lines for long builds)
gh api repos/projectbluefin/dakota/actions/jobs/<job-id>/logs > /tmp/bst-live.log

# 3. Count cache hits vs elements being compiled
grep -c "SKIPPED" /tmp/bst-live.log          # cache hits
grep "Running commands" /tmp/bst-live.log | tail -20  # what's actively building

# 4. See which upstream elements are being compiled (indicates junction drift)
grep "START.*Running commands" /tmp/bst-live.log | grep -oE "\[.*\]" | sort -u
```

**Important:** The live log endpoint is a snapshot, not a stream. For builds
running > ~90 minutes, the log may be stale by 60–90 minutes relative to current
wall-clock time. If the last log timestamp is behind by > 1 hour, the build is
still running but log data is not being returned. Use `gh api
repos/.../actions/runs/<id>/jobs` to confirm `status: in_progress`.

**Deciding whether to re-trigger:** A build making steady progress on
gnome-build-meta `core-deps/` elements is normal cache-warming after a GNOME
nightly — let it run. Only re-trigger if:
- The run hits a timeout error
- Elements are stuck "Waiting for the remote build to complete" for > 30 min (CAS issue)
- The build failed with a compilation error

### gnome-build-meta nightly delta builds (2026-06-07)

The GNOME upstream nightly (~08:00 UTC) updates a batch of `core-deps/` elements
in gnome-build-meta. The first build that runs after a nightly must recompile
those elements from scratch. This is **expected and not a problem.**

**Typical pattern:**
- 1,000+ elements: SKIPPED (cache hits from the previous build)
- 10–30 `core-deps/` elements: recompiled (changed in nightly)
- Each element compiles in 1–5 minutes; total extra time: ~60–120 minutes
- Build completes well within the 330-minute timeout

**Elements commonly rebuilt after a nightly:** `protobuf`, `folks`, `sofia-sip`,
`procps`, `containers-common`, `libvirt-glib`, `spice-gtk`, `foundry`, `feedbackd`,
`jsonrpc-glib`, `libgit2-glib`.

**How to confirm it's a nightly delta (not a cache bust):**
```bash
# Check which junction commit the failing build used:
grep "Fetching from.*gnome-build-meta" /tmp/bst-live.log

# Compare to the junction ref pinned in the element:
grep "ref:" elements/gnome-build-meta.bst
```
If the junction ref in `elements/gnome-build-meta.bst` matches what the build
fetched, the cache miss is upstream drift, not a local element change.

**After a nightly delta completes**, subsequent builds are fast again (< 90 min)
because all newly-compiled elements land in the remote CAS.

### Diagnosing a build timeout (330-minute limit) (2026-06-07)

A build that hits the 330-minute GitHub Actions timeout shows:
```
The action 'Build OCI image with BuildStream' has timed out after 330 minutes.
```

No element "failed" — the build was still running. Download the logs to find what
was active at timeout:

```bash
gh run download <run-id> --repo projectbluefin/dakota \
  --name buildstream-logs-x86_64-default -D /tmp/bst-logs

# Find elements that were waiting for remote execution when the timeout hit:
grep -rl "Waiting for the remote build to complete" /tmp/bst-logs/ | while read f; do
  tail -1 "$f" | grep -q "Waiting" && echo "$f"
done

# Find the latest-timestamped log files (actively building at timeout):
find /tmp/bst-logs -name "*.log" | grep -oP '\d{8}-\d{6}' | sort | tail -10
```

**Root causes of timeouts:**

| Cause | Signal | Fix |
|---|---|---|
| Element change invalidated CAS artifact | Many elements building from scratch (600+), cold build of all dependents | Revert the element change; put machine-local workarounds in userconfig |
| CAS server slow / degraded | Elements stuck "Waiting for the remote build to complete" for hours | Check CAS health; re-trigger after recovery |
| Single very slow element (e.g. webkitgtk) is a bottleneck | One element dominates build time | Normal; just needs a warm cache hit |

**After fixing the root cause**, the re-triggered build will use the existing CAS
artifacts for all elements whose cache keys are unchanged — typically a warm build
completes in under 90 minutes.

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
- name: Install Syft (fallback)
  if: steps.sbom_artifact.outcome == 'failure'
  id: syft
  uses: anchore/sbom-action/download-syft@<SHA> # v0
  with:
    syft-version: v1.44.0
- name: Generate SBOM with Syft (fallback)
  if: steps.sbom_artifact.outcome == 'failure'
  env:
    SYFT_CMD: ${{ steps.syft.outputs.cmd }}
  run: "${SYFT_CMD}" "ghcr.io/.../dakota@${DIGEST}" -o spdx-json=sbom-current/dakota.spdx.json
```
Use `anchore/sbom-action/download-syft` (SHA-pinned) instead of `curl .../main/install.sh | sh`.
The `@main` install script is a mutable supply-chain input even when the version flag is pinned.

### release.yml publish run search must include merge-queue branches (2026-06-07)

`gh run list --branch main` only returns runs whose triggering branch was exactly
`main`. Publish runs triggered by `workflow_run` from `gh-readonly-queue/main/**`
(i.e., merge queue builds) are associated with the queue branch, not `main`, in
the GitHub API. If the promoted `:stable` SHA came from a merge-queue run, the
`--branch main` filter silently misses it and `release.yml` exits with "no
successful publish run found."

**Fix:** Drop the `--branch filter and filter by `headBranch` in jq instead:
```bash
gh run list \
  --workflow "Publish Bluefin dakota" \
  --status success \
  --limit 100 \
  --json headSha,headBranch,createdAt,databaseId \
  | jq -r --arg sha "$SHA" '
      map(select(
        .headSha == $sha and
        (.headBranch == "main" or (.headBranch | test("^gh-readonly-queue/main/")))
      )) | .[0] // empty'
```

### workflow_dispatch on publish.yml can promote non-main refs to :testing (2026-06-07)

`publish.yml` has no branch guard on the `promote` job. A manual dispatch from a
non-main branch flows through e2e and promotes to `:testing`, fast-forwarding the
`testing` branch to an unmerged commit.

**Fix:** Add a branch guard to the `promote` job. Since `e2e-gate` no longer
exists (continuous build model), the guard goes directly on `promote`:
```yaml
promote:
  needs: [setup, publish]
  if: >-
    needs.publish.result == 'success' &&
    (github.event_name == 'workflow_run' || github.ref_name == 'main')
```
`workflow_run` events are always safe (they trigger from completed `main`/merge-queue
builds per the trigger filter in `publish.yml`). Only manual dispatches need the
`github.ref_name == 'main'` guard.

### release.yml manual dispatch TOCTOU (2026-06-07)

In `workflow_dispatch` mode with no `source_sha`, the original code resolved SHA
and digest in two separate `skopeo inspect` calls. If `:stable` moved between
them, the release would pair a wrong SHA with a wrong digest.

**Fix:** One `skopeo inspect --format '{{index .Labels "org.opencontainers.image.revision"}} {{.Digest}}'`
call extracts both values atomically. Write the digest to `$GITHUB_ENV` and read
it in the next step — no second skopeo call.

```bash
INSPECT=$(skopeo inspect --format \
  '{{index .Labels "org.opencontainers.image.revision"}} {{.Digest}}' \
  docker://ghcr.io/.../dakota:stable)
SHA=$(echo "${INSPECT}" | awk '{print $1}')
STABLE_DIGEST=$(echo "${INSPECT}" | awk '{print $2}')
echo "STABLE_DIGEST=${STABLE_DIGEST}" >> "$GITHUB_ENV"
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

### check-diff skip silently skips missing variant :stable tags (2026-06-08)

`check-diff` compares `dakota:testing` vs `dakota:latest` only. If they match,
`has_diff=false` and the entire `promote` matrix is skipped — including the
nvidia variant. This means if `dakota-nvidia:stable` was never created (e.g.,
nvidia `:testing` didn't exist during the first promotion that set `:latest`),
it will silently never get set on subsequent runs where the default image hasn't
changed.

**How it breaks:**

1. First promotion: NVIDIA `:testing` not found → `has_nvidia=false` → nvidia skipped
2. Next promotion: NVIDIA `:testing` now exists, but `dakota:testing == dakota:latest`
   → `has_diff=false` → entire promote job skipped → `dakota-nvidia:stable` never set

**Fix (manual):** Copy from the matching `:testing` digest directly:

```bash
# Confirm revision matches dakota:stable
skopeo inspect docker://ghcr.io/projectbluefin/dakota:stable \
  | jq '.Labels["org.opencontainers.image.revision"]'
skopeo inspect docker://ghcr.io/projectbluefin/dakota-nvidia:testing \
  | jq '.Labels["org.opencontainers.image.revision"]'

# Get the testing digest
DIGEST=$(skopeo inspect docker://ghcr.io/projectbluefin/dakota-nvidia:testing \
  | jq -r '.Digest')

# Copy to :stable (login with gh auth token first)
GH_TOKEN=$(gh auth token)
skopeo login ghcr.io --username <your-user> --password "$GH_TOKEN"
skopeo copy \
  "docker://ghcr.io/projectbluefin/dakota-nvidia@${DIGEST}" \
  "docker://ghcr.io/projectbluefin/dakota-nvidia:stable"
```

**Underlying bug:** `check-diff` should also detect missing variant stable tags
and set `has_diff=true` in that case, forcing the promote job to run even when
the default image hasn't changed.

### Testing branch fast-forward is idempotent — GitHub API 422 on same SHA (2026-06-08)

**Symptom:** `publish.yml` promote job fails with:
```
{"message":"Update is not a fast forward",...}
{"message":"Reference already exists",...}
```
Exit code 1 even though the image was published successfully.

**Root cause:** The original fast-forward step used a PATCH-then-POST fallback:
1. PATCH `refs/heads/testing` → GitHub returns 422 "Update is not a fast forward" when
   the ref is already at the target SHA (no-op case)
2. POST fallback → GitHub returns 422 "Reference already exists"

Both fail, causing the step to fail even though nothing needed updating.

**Fix:** Check the current SHA first; only PATCH or POST when actually needed:
```yaml
CURRENT_SHA=$(gh api repos/${{ github.repository }}/git/refs/heads/testing \
  --jq .object.sha 2>/dev/null || echo "")
if [ "$CURRENT_SHA" = "$BUILD_SHA" ]; then
  echo "testing branch already at $BUILD_SHA — nothing to do"
elif [ -z "$CURRENT_SHA" ]; then
  gh api repos/${{ github.repository }}/git/refs --method POST \
    --field ref="refs/heads/testing" --field sha="$BUILD_SHA"
else
  gh api repos/${{ github.repository }}/git/refs/heads/testing \
    --method PATCH --field sha="$BUILD_SHA" --field force=false
fi
```

### Merge-queue head_branch is never 'main' — use startsWith guard (2026-06-08)

When a PR merges via GitHub's merge queue, `github.event.workflow_run.head_branch`
(and `needs.setup.outputs.branch`) is `gh-readonly-queue/main/pr-N`, **never** `main`.

Any `if:` condition that checks `branch == 'main'` will silently skip for all
merge-queue merges (i.e., every normal PR merge).

**Correct pattern:**
```yaml
if: >-
  matrix.image_suffix == '' &&
  (needs.setup.outputs.branch == 'main' ||
   startsWith(needs.setup.outputs.branch, 'gh-readonly-queue/main/'))
```

### :next/:btw stream — fully automated, no human gate (2026-06-08)

The `next` branch (`:next`/`:btw` tags) is a continuously rolling GNOME OS
nightly stream. Junction bumps on `next` use auto-merge — no human review
required. This is intentional and differs from core junction bumps on `main`
(which require human review per `track-bst-sources.yml`).

`track-next-junctions.yml` schedules nightly junction tracking on the `next`
branch. PRs it opens get auto-merged once required checks pass.

### export/publish jobs must skip storage-service — remote CAS quota too small for GNOME 51 (2026-06-09)

**Symptom:** `bst export` in the publish job fails with:
```
OutOfSpaceException: Insufficient storage quota
errMsg = "Insufficient storage quota" (buildboxcommon_lrulocalcas.cpp:383)
```
The blob is `~8.5 GB` (GNOME 51 root artifact is significantly larger than GNOME 50).

**Root cause:** `cache.storage-service` in the BST config routes the local casd
through `cache.projectbluefin.io`. The remote server's per-client storage quota
is exceeded when materialising the full artifact for export. Build jobs are fine
because they write blobs incrementally as they are built; export pulls the entire
artifact at once.

**Fix (already in `generate-bst-ci-config/action.yml`):**
`cache.storage-service` is only written when `enable-push: true` (build jobs).
Export/publish jobs (`enable-push: false`) use local disk for the casd.
The runner's BTRFS volume has sufficient space for export.

**Do not revert this.** Any future regression will show this same symptom on
the `next`/`:btw` stream, which produces the largest artifacts.

### First cold build of next branch will timeout — retrigger until cache warms (2026-06-09)

The `next` branch tracks gnome-build-meta `master` (GNOME 51+). The first build
after branching or a major gnome-build-meta ref bump is a **full cold build** of
the entire GNOME stack — ~700+ elements. This exceeds the 330-minute GHA timeout.

**This is expected and normal.** Each run pushes built artifacts to
`cache.projectbluefin.io`. Simply retrigger the build — each run picks up from
where the previous one left off:

```bash
gh workflow run build.yml --repo projectbluefin/dakota --ref next
```

Typically takes 2–3 runs to warm the full cache. Subsequent builds (after
junction bumps) are incremental (~3–25 min).

**Indicator that cache is warm:** build jobs complete in <5 minutes — all
artifacts are cache hits and no compilation occurs.

### next branch needs manual cherry-picks of main fixes (2026-06-09)

`next` is a long-lived parallel branch. Bug fixes merged to `main`
(e.g., sbom crun fixes, CI improvements) do **not** automatically land on `next`.

Before debugging a failure on `next`, check if the same fix is already on `main`:

```bash
git log upstream/next..upstream/main --oneline -- Justfile .github/
```

Cherry-pick selectively:
```bash
git checkout upstream/next -b fix/next-sync
git cherry-pick <sha1> <sha2> <sha3>
git push upstream fix/next-sync:next
```

Commits to watch for: any `fix(sbom):`, `fix(ci):`, or `fix(publish):` commits
on `main` that touch `Justfile` or `.github/`.

### :next build only fires on junction bumps — not a guaranteed nightly (2026-06-09)

`build.yml` has no `schedule:` trigger. The `next` branch builds when:
1. `track-next-junctions.yml` bumps gnome-build-meta master (20:00 UTC nightly,
   only if upstream advanced that day) → auto-merge PR → merge_group build
2. Manual `workflow_dispatch`

On days where gnome-build-meta `master` does not advance, **no build fires**.
For a guaranteed nightly, a `schedule:` trigger on `next` is needed in
`build.yml`. This is a known gap — track it if builds go stale.

### publish.yml must include testing branch in workflow_run.branches (2026-06-10)

`publish.yml` originally only listed `main`, `gh-readonly-queue/main/**`, `next`,
and `gh-readonly-queue/next/**` in `workflow_run.branches`. Auto-merge tracking
PRs target `testing` — their builds completed successfully but no image was ever
published. `promote-testing-to-main.yml` fires on `push: branches: [testing]` and
immediately does `skopeo inspect dakota:testing`, which silently failed every time
testing advanced without a prior main publish.

**Fix (PR 766):** add `testing` and `gh-readonly-queue/testing/**` to the
`workflow_run.branches` filter, extend the `setup` job `if` condition, and map
`testing` branch → `testing_tag=testing`. Match bluefin/bluefin-lts: every merge
to testing publishes `:testing` immediately.

### track-bst-sources: branch from origin/$BASE_BRANCH, not origin/main (2026-06-10)

`track-bst-sources.yml` created auto-merge tracking branches from `origin/main`
but targeted `testing`. When main and testing had diverged on workflow files, the
PR diff included those CI changes in reverse — the PR appeared to be deleting
them. PR 764 had 18 commits and would have removed `testing` from `build.yml`
triggers and deleted `renovate-automerge.yml`. It was closed as a corrupted PR.

**Corrupted auto-track PR anatomy:** CONFLICTING state, 10+ commits, diff shows
CI workflow regressions (removes triggers, deletes workflows). The element file
contents match the base branch — no real update present.

**Fix (PR 766):** determine `BASE_BRANCH` before `git checkout`, stash the
BST-tracked element changes, `git checkout -B "$BRANCH" "origin/$BASE_BRANCH"`,
then `git stash pop`. The PR diff is now relative to the target branch only.

### track-bst-sources: auto-merge silently never set — use --squash not --merge (2026-06-10)

The repo has `allowMergeCommit=false` (only squash merges permitted). The
workflow called `gh pr merge --auto --merge` which hit the `|| echo ::warning::`
fallback — auto-merge was never set on any tracking PR. They sat unmerged
indefinitely with no visible error.

**Fix (PR 767):** `--merge` → `--squash`. The `renovate-automerge.yml` already
used `--squash` correctly; `track-bst-sources` was the gap.

**Diagnostic:** if a tracking PR has auto-merge null and validate passed, check
`allowMergeCommit` on the repo before assuming a workflow bug.


### `permissions: {}` at workflow level starves GITHUB_TOKEN for reusable job calls (2026-06-11)

Setting `permissions: {}` at the **workflow** level and then specifying
permissions at the **job** level does NOT work when the job uses `uses:` to
call a reusable workflow. GitHub mints the `GITHUB_TOKEN` at the calling
workflow's top-level scope — job-level `permissions:` can only restrict, not
expand beyond that ceiling.

**Symptom:** `startup_failure` with `jobs: []` (zero jobs started) on every
run of a thin caller that uses `uses:` with its own `permissions:` block.

**Fix:** Set the top-level `permissions:` to the superset of everything any job
in the workflow needs:

```yaml
# WRONG — starves the token; jobs cannot escalate beyond {}
permissions: {}

jobs:
  promote:
    permissions:
      contents: write
      pull-requests: write
    uses: org/actions/.github/workflows/reusable.yml@SHA

# CORRECT — top-level is the budget; job-level can reduce but not expand
permissions:
  contents: write
  packages: read
  pull-requests: write
  issues: write

jobs:
  promote:
    uses: org/actions/.github/workflows/reusable.yml@SHA
```

**Affected workflows fixed 2026-06-11:** `promote-testing-to-main.yml` (#796),
`execute-release.yml` (#798).

### `pull_request: closed` trigger causes `startup_failure` for all non-promotion merges (2026-06-11)

When a workflow uses `on: pull_request: types: [closed]` and ALL jobs have
`if:` conditions that evaluate to `false` for non-promotion PRs, GitHub reports
the workflow run as `startup_failure` instead of a clean skip. This produces
alarming noise in every PR merge and masks real failures.

**Symptom:** `execute-release.yml` showed `startup_failure` on every single PR
merged to `main` from the day it was introduced — 25+ runs, none successful,
all with `jobs: []`.

**Correct pattern (from bluefin-lts):** Use `push: branches: main` +
`workflow_dispatch`, then add a lightweight `check-trigger` job that reads
the squash-merge commit message:

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  check-trigger:
    runs-on: ubuntu-latest
    outputs:
      is-promotion: ${{ steps.check.outputs.is-promotion }}
    steps:
      - id: check
        env:
          COMMIT_MSG: ${{ github.event.head_commit.message }}
          EVENT_NAME: ${{ github.event_name }}
        run: |
          if [ "$EVENT_NAME" = "workflow_dispatch" ]; then
            echo "is-promotion=true" >> "$GITHUB_OUTPUT"
          elif echo "$COMMIT_MSG" | grep -q "^ci: promote testing images to stable"; then
            echo "is-promotion=true" >> "$GITHUB_OUTPUT"
          else
            echo "is-promotion=false" >> "$GITHUB_OUTPUT"
          fi

  execute:
    needs: [check-trigger]
    if: needs.check-trigger.outputs.is-promotion == 'true'
    uses: ...
```

When `is-promotion=false`, `check-trigger` succeeds cleanly and subsequent
jobs are skipped — no `startup_failure`.

**Fixed:** `execute-release.yml` PR #800, 2026-06-11.

### CODEOWNERS: no-owner override for auto-managed files (2026-06-11)

Files auto-managed by a bot (e.g. `elements/bluefin/common.bst` bumped by
mergeraptor on every common release) should not trigger code-owner review
requests. Add a no-owner line for the specific file **above** the catch-all
path rule — CODEOWNERS is evaluated top-to-bottom and the first match wins:

```
# Auto-managed by mergeraptor — no review required
elements/bluefin/common.bst

# Everything else in elements/ needs a maintainer review
elements/ @projectbluefin/maintainers
```

Also add the bot to `bypass_pull_request_allowances` in the repo's branch
protection ruleset so it can satisfy the `required_approving_review_count`
without a human approval. Without this, auto-merge is set but never clears.

**Fixed:** PR #807, 2026-06-11.

### CODEOWNERS: use team slugs, not individual handles (2026-06-11)

Individual `@handle` entries in CODEOWNERS mean:
- New team members are never auto-requested for review
- Departed maintainers keep getting pinged
- Team membership changes require a CODEOWNERS PR

**Fix:** Use `@org/team-slug` instead:

```
# WRONG
* @castrojo @p5 @m2Giles @tulilirockz

# CORRECT
* @projectbluefin/maintainers
```

**Fixed:** PR #796, 2026-06-11.

### Promotion PR noise: suppress CodeRabbit with `@coderabbitai ignore` (2026-06-11)

CodeRabbit posts review summaries on every PR, including automated promotion
PRs that only touch `.github/release-state.yaml`. To suppress it, add this
HTML comment as the **first line** of the PR body:

```markdown
<!-- @coderabbitai ignore -->
```

Added to `reusable-promote.yml` in `projectbluefin/actions` (commit f5cd16ce).

### Promotion PR body: include release context for maintainer decision-making (2026-06-11)

The old promotion PR body was a raw YAML dump. Maintainers had no context for
deciding whether to merge. The rich body template now includes:

| Field | Source |
|---|---|
| Days since last stable | `gh release list --limit 1 --json publishedAt` |
| Commits since last stable | `git rev-list --count $LAST_PROMOTE_SHA..origin/main` |
| Component old→new refs | `git show $LAST_SHA:elements/gnome-build-meta.bst` vs current |
| Images table | Parsed from `.github/release-state.yaml` |

Change indicator `⬆` appears when a junction ref changed since the last
promotion.

**Location:** `reusable-promote.yml` "Open or update promotion PR" step in
`projectbluefin/actions`.

### GitHub Release body limit: 125k characters (2026-06-11)

`gh release create --notes-file release-notes.md` fails with HTTP 422 if the
body exceeds GitHub's hard limit of 125,000 characters:

```
HTTP 422: Validation Failed
body is too long (maximum is 125000 characters)
```

The release notes generator in `reusable-release.yml` can produce bodies larger
than this limit when the SBOM diff or changelog is long (e.g. after 12+ days
between stable releases).

**Fixed in `projectbluefin/actions#191`:** `reusable-release.yml` now hard-caps
the release body at 120,000 characters with a `…` trailer before calling
`gh release create`. No manual intervention needed.

### `sign-and-publish` reusable action: cert identity regexp must include consuming repo (2026-06-11)

The `sign-and-publish` action in `projectbluefin/actions` has a default
`certificate-identity-regexp` that is repo-specific. If the pinned SHA
pre-dates when `dakota` was added to that regexp, every `publish.yml` run
fails at the cosign verification step — 100% failure rate.

**Symptom:** publish run fails at cosign verify with a cert identity mismatch.
All `:testing` builds stop. May appear as "65%" failure rate if some older
cached `:testing` images still serve.

**Fix:** Bump the `projectbluefin/actions` SHA to a commit that includes
the repo name in the default regexp. Or pass an explicit input:

```yaml
- uses: projectbluefin/actions/.github/actions/sign-and-publish@<SHA>
  with:
    cosign_identity_regexp: >-
      ^https://github\.com/projectbluefin/(dakota|actions)/\.github/workflows/
```

**Root cause (PR #792, 2026-06-11):** Actions SHA `3025b5d31f34` excluded
`dakota`; bumping to `2a09e72e9be1` (actions#166) fixed it.

**Rule:** after bumping any `projectbluefin/actions` SHA, verify the first
publish run succeeds before assuming the bump is clean.

### `cliff.toml` required at repo root for structured release notes (2026-06-11)

`reusable-release.yml` calls `git-cliff` via the `generate-release-notes`
step. Without `cliff.toml` at the repo root, it falls back to a raw
`git log` heredoc — no commit grouping, no filtering, no section headers.

**Add `cliff.toml`** adapted from `projectbluefin/common/cliff.toml` with
Conventional Commits parser. Dakota-specific note: **omit** the
`chore: promote` skip rule. Dakota uses OCI digest promotion via the
`execute-release.yml` commit-message gate — there are no squash promotion
commits in the git history that need filtering out.

**Key sections in `cliff.toml`:**

```toml
[git]
conventional_commits = true
filter_unconventional = false
tag_pattern = "v[0-9].*"
skip_tags = ""

[git.commit_parsers]
# do NOT add: { message = "^chore: promote", skip = true }
# Dakota promotions don't produce commits like this
```

**Added in PR #793, 2026-06-11.** Closes projectbluefin/common#609.

### `gh pr merge --auto` does NOT honour `bypass_pull_request_allowances` (2026-06-12)

`gh pr merge "$PR_URL" --auto --squash` enables GitHub's **auto-merge queue**.
The queue evaluates branch-protection conditions using GitHub's internal process
and does **not** honour `bypass_pull_request_allowances`. So a bot app in the
bypass list that enables auto-merge still sees the PR sit open waiting for a
human approval that will never arrive automatically.

**Only direct merges (without `--auto`) use the bypass.**

**Symptom:** all `auto-merge` group PRs from `track-bst-sources.yml` (common,
distrobox, brew, shell extensions, etc.) were sitting open indefinitely despite
`required_approving_count: 1` and the bot in `bypass_pull_request_allowances`.

**Fix (PR #820):** remove `--auto` from the merge call. Since there are no
required status checks, the direct merge completes immediately on PR creation.

```bash
# ✗ — queued auto-merge, bypass ignored
gh pr merge "$PR_URL" --auto --squash

# ✓ — direct merge, bypass honoured
gh pr merge "$PR_URL" --squash
```

**Rule:** use `--auto` only when you want to wait for required CI checks to pass
AND the merging actor has no bypass. For bypass actors merging bot-managed PRs
with no required checks, drop `--auto`.

### Caller-level `permissions:` must be a superset of all reusable workflow job permissions (2026-06-12)

When a thin-caller workflow calls a reusable workflow via `uses:`, the
**caller's top-level `permissions:` block caps what GITHUB_TOKEN can do** in
every job inside the reusable. If the reusable's job needs `packages: read` or
`actions: read` and the caller only declares `contents: write`, those scopes
are silently restricted to `none` — producing `startup_failure with jobs: []`.

**Symptom:** `promote-testing-to-main.yml` had `startup_failure` on every run
after the thin-caller migration (PR #811). Missing `packages: read` (for GHCR
digest lookups) and `actions: read` (for workflow-run status checks) were not
in the caller's `permissions:` block.

**Fix (PR #817):** declare every scope the reusable's jobs need at the
caller's top level:

```yaml
permissions:
  contents: write       # push squash promotion branch
  pull-requests: write  # create / update / auto-merge the promotion PR
  issues: write         # open / close failure-tracking issues
  packages: read        # read image digests in release-gate checks
  actions: read         # inspect workflow-run statuses in release-gate
```

**Rule when writing thin callers:** read the reusable workflow's job-level
`permissions:` blocks and make the caller's top-level `permissions:` a strict
superset of the union of all of them.

### SHA-pinning a reusable that itself has nested SHA-pinned calls — inner SHA must still exist (2026-06-12)

When you SHA-pin a reusable workflow (e.g.
`projectbluefin/actions/.github/workflows/reusable-promote-squash.yml@<sha>`),
GitHub validates the **full call chain at startup** — including any
`uses:` references inside the pinned reusable. If the pinned reusable
internally calls another workflow at a now-deleted SHA, the calling workflow
fails with:

```
failed to parse workflow: error parsing called workflow
--> "projectbluefin/actions/.github/workflows/reusable-release-gate.yml@<dead-sha>"
: failed to fetch workflow: workflow was not found.
```

This manifests as `startup_failure` on the **outer** caller — the error is not
visible without running the workflow and reading the dispatch HTTP response.

**Cause in this session:** the bluefin SHA for `reusable-promote-squash.yml`
(`5f3cab`) internally called `reusable-release-gate.yml@5f8abb` which had been
removed from the `actions` repo. The original dakota SHA (`6c2278`) internally
calls `reusable-release-gate.yml@v1` (the managed tag), which remains valid.

**Fix (PR #819):** revert to the SHA whose nested calls use `@v1` tags rather
than pinned SHAs for inner dependencies.

**Rule:** when picking a SHA to pin for a reusable workflow, verify that its
own nested `uses:` references are either `@v1`/managed-tags or still-live
SHAs. Prefer the version that uses managed tags internally — those age better.

---

## Testing→main promotion pipeline — full cycle and failure modes (2026-06-12)

### How the cycle works (bluefin model)

```
Renovate PR → testing branch (automerges when build CI passes)
    → push to testing → promote-testing-to-main fires
    → squash PR: auto/promote-testing-to-main → main
    → maintainer merges
    → execute-release fires (commit msg "ci: promote testing images to stable")
    → :testing retagged as :stable
    → push to main → sync-main-to-testing fires
    → main fast-forwarded into testing (testing == main again)
    → next Renovate cycle begins
```

### Three invariants that must all hold

1. **`baseBranchPatterns: ["testing"]`** in `renovate.json5` — Renovate must target
   `testing`, not `main`. With `baseBranchPatterns: ["main"]`, `testing` is a dead
   branch: nothing ever lands there, the promote workflow finds nothing to squash,
   and `:stable` never updates.

2. **`sync-main-to-testing.yml`** must exist — after each squash-merge promotion, the
   squash commit lands on `main` but not `testing`. Without this workflow, `testing`
   falls permanently behind `main`. The next promote run finds diverged trees (so
   `sync_needed=true`), but the squash produces nothing staged → `git commit` exits 1.

3. **`pr-triage.yml` must exempt `renovate/*` PRs targeting `testing`** — the triage
   workflow blocks all PRs not targeting `main`. Without an exemption, Renovate PRs
   to `testing` are immediately blocked and cannot automerge.

### The empty-squash crash (known bug in reusable-promote-squash)

When `testing` is behind `main` with no unique content:
- `git merge --squash origin/testing` says "Already up to date"
- Nothing is staged
- `git commit` exits 1 → job fails with misleading error

This is fixed by `projectbluefin/actions#218` (adds `git diff --cached --quiet` guard
before `git commit`). In steady state (sync-main-to-testing present), this edge case
doesn't occur because `testing == main` after each sync, and the next promote run gets
`sync_needed=false` cleanly. The fix is defence-in-depth.

### Root cause of 2026-06-11/12 breakage

PR #741 changed `baseBranchPatterns` from `["testing"]` to `["main"]` to work around
the triage gate — but without also adding `sync-main-to-testing.yml` or exempting
Renovate from the gate. After promotion #797 (June 10), the cycle broke permanently:
- `testing` fell 20+ commits behind `main` (no sync workflow)
- Renovate stopped feeding `testing` (wrong base branch)
- Promote workflow crashed nightly (empty squash)
- `:stable` stopped updating

**Fix: PR #822** (dakota) + **PR #218** (actions).

### `gh pr merge --auto` also fails when target branch has NO branch protection (2026-06-13)

The `--auto` lesson above covers the bypass case (protection exists but bypass
not honoured). There is a second, distinct failure mode: if the target branch
has **zero branch protection rules** (no ruleset, no classic protection),
`gh pr merge --auto` fails immediately with:

```
GraphQL: Pull request Protected branch rules not configured for this branch
        (enablePullRequestAutoMerge)
```

`testing` has no branch protection by design. Any automerge workflow targeting
`testing` with `--auto` will always fail. The fix (applied in `projectbluefin/actions`
`renovate-automerge.yml` `@v1`) is to drop `--auto` entirely — CI success is
already guaranteed by the `workflow_run` trigger condition.

**Two distinct `--auto` failure modes:**

| Failure | Error | Cause | Fix |
|---|---|---|---|
| Bypass not honoured | Queued but never merges | Branch has protection, bot in bypass, but `--auto` ignores bypass | Drop `--auto`, use direct merge |
| No protection at all | `Protected branch rules not configured` | Branch has zero protection rules | Drop `--auto`, use direct merge |

**Diagnosis:** check `gh api repos/<owner>/<repo>/branches/<branch> --jq '.protected'`.
If `false`, drop `--auto`. If `true`, check whether the token is in `bypass_actors`.

### `workflow_run` always uses the DEFAULT BRANCH's workflow file (2026-06-13)

When a workflow has `on: workflow_run`, GitHub runs it from the **repository's
default branch** — not from the branch that triggered the upstream workflow run.

**Consequence for automerge fixes:** if `renovate-automerge.yml` is fixed on a
feature branch or `testing` but the fix hasn't landed on `main` (the default
branch), every new `workflow_run` trigger still runs the old broken version from
`main`. The fix takes effect only when it merges to `main`.

**Implication:** fixes to `workflow_run`-triggered workflows that land on `testing`
(via a Renovate-style staging flow) are effectively inert until the promote PR
merges them to `main`.

### Internal projectbluefin/ actions: use @v1 managed tag, not SHA pins (2026-06-13)

SHA-pinning internal org actions (`projectbluefin/actions`) is
counter-productive and was the root cause of the June 13 automerge outage:

- The `--auto` bug was committed on June 7 at SHA `fcd2a6bac15f`
- Every consumer (dakota, bluefin, bluefin-lts, common) pinned different
  intermediate SHAs, all carrying the broken `--auto`
- Fixes require N separate Renovate bump PRs — one per consumer — each
  lagging by hours or days
- `main` and `testing` diverged to different SHAs, creating split-brain

**AGENTS.md already states the policy:**
> `projectbluefin/` refs (`@v1`, `@main`) are intentional managed tags and are exempted.

Use `@v1` — it moves forward with every non-breaking fix and is maintained by
the org. `@v1.0.0` and `@v1.1.0` are static point-release tags if you need
a pinned version.

```yaml
# ✗ — SHA pin, breaks propagation; 7 different SHAs across 10 files
uses: projectbluefin/actions/bootc-build/setup-runner@2a09e72e... # v1.1.0

# ✓ — managed tag, fixes propagate instantly
uses: projectbluefin/actions/bootc-build/setup-runner@v1
```

**Enforcement:** `no-sha-pins-for-internal-actions` pre-commit hook blocks any
future `projectbluefin/.*@<sha>` commits.

**External actions** (`actions/checkout`, `taiki-e/install-action`, etc.) remain
SHA-pinned — that policy is unchanged and correct.

### build.yml push trigger must include `testing` for `:testing` images (2026-06-13)

`build.yml` had `push: branches: [main, next]` — `testing` was missing.
`publish.yml` already listed `testing` in its `workflow_run.branches` filter
and had logic to publish `:testing` on testing-branch builds, but that path
was dead because `build.yml` never triggered on push to `testing`.

**Result:** `:testing` images were never updated by Renovate merges to testing.
The promote PR was always building from stale image content.

**Fix (PR #830):** add `testing` to `build.yml`'s push trigger. The build job
runs on `event_name != 'pull_request'`, so push-to-testing fires the full build.
BST artifact cache steps remain gated on `merge_group || schedule || workflow_dispatch`
(intentional quota management) — they skip for plain pushes, which is fine.

### publish.yml: 4-job pipeline after speed-up refactor (2026-06-12)

`publish.yml` was restructured to remove three major bottlenecks. New job graph:

```
setup → publish-image → promote     (critical path to :testing: ~50–80 min)
              └──────→ publish-sbom  (runs in parallel with promote)
```

**Job renames / splits:**
- `publish` renamed to `publish-image` — exports OCI, pushes `:$sha`, signs. No SBOM.
- `publish-sbom` (new) — depends on `publish-image`, runs in parallel with `promote`.
  Contains: SBOM generation, artifact upload, oras attach, cosign sign SBOM.
- `promote` — now depends on `publish-image` only (not SBOM). Saves 10–15 min.

**skopeo copy in promote (P1):**
The old `podman pull → tag → push` pattern transferred the full 8.5 GB image
round-trip for each re-tag. Replace with:
```bash
skopeo copy \
  --preserve-digests \
  --src-creds "$GH_ACTOR:$GH_TOKEN" \
  --dest-creds "$GH_ACTOR:$GH_TOKEN" \
  "docker://${IMAGE}:${BUILD_SHA}" \
  "docker://${IMAGE}:${TESTING_TAG}"
```
`--preserve-digests` is **mandatory** — it keeps the promoted tag pointing at
the same manifest digest that cosign signed. Omitting it causes GHCR to re-encode
layers and produce a new digest that breaks the signature chain.
`skopeo` is pre-installed on ubuntu-24.04 runners — no install step needed.

**SBOM pip cache (P3):**
`buildstream-sbom` is installed from a GitLab git URL every run (3–8 min with
retries). Cache the pip wheel at `~/.cache/pip` keyed to the pinned commit SHA:
```yaml
- uses: actions/cache@<SHA>
  with:
    path: ~/.cache/pip
    key: pip-sbom-<pinned-commit-sha>
    restore-keys: pip-sbom-
```
Mount into the bst2 container via `-v "${HOME}/.cache/pip:/root/.cache/pip:rw"`
in the `just sbom` podman run call. Update the cache key when the pin is bumped.

**buildah replaces squash-all in just export (P6):**
`podman build --squash-all` re-encoded the entire 8.5 GB image for a 2-line
`sed` edit to `/usr/lib/os-release`. Replace with:
```bash
CONTAINER=$(buildah from "$IMAGE_ID")
MOUNT=$(buildah mount "$CONTAINER")
sed -i "s/^VERSION_ID=.*/VERSION_ID=\"${DATE_TAG}\"/" "$MOUNT/usr/lib/os-release"
sed -i "s/^IMAGE_VERSION=.*/IMAGE_VERSION=\"${DATE_TAG}\"/" "$MOUNT/usr/lib/os-release"
buildah config --label "org.opencontainers.image.created=..." "$CONTAINER"
buildah commit --rm "$CONTAINER" "${FINAL_NAME}:${FINAL_TAG}"
```
`buildah commit` (no `--squash`) appends a tiny (~1 KB) delta layer. `chunka`'s
BST path calls `podman image mount` which returns a merged overlayfs view
regardless of layer count — multi-layer input is transparent to chunkah.
`buildah` is pre-installed by `setup-runner@v1` (resolute package).

**digest re-derivation in publish-sbom:**
`publish-sbom` needs the image digest for `oras attach` but GHA matrix job
outputs are fragile. Re-derive it with `skopeo inspect` instead:
```bash
DIGEST=$(skopeo inspect \
  --creds "$GH_ACTOR:$GH_TOKEN" \
  "docker://${IMAGE}:${BUILD_SHA}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['Digest'])")
```
No inter-job output wiring needed. The image was pushed by `publish-image` and
is immediately available in GHCR before `publish-sbom` starts.

**cache-warm cron: Mon–Fri (P4):**
Changed from `0 6 * * 1,4` (Mon/Thu) to `0 6 * * 1-5` (Mon–Fri).
A junction ref bump on Tuesday left the CAS cold for 3 days, causing build.yml
to timeout at 360 min. Daily warming caps the cold window at 1 day.

### Promotion PR: force-push dismisses approvals even when diff is unchanged (2026-06-13)

When `main` advances (e.g. Renovate merges) while a promotion PR has a
maintainer approval, the promote workflow was rebuilding the squash branch
and force-pushing — even though the effective diff against `main` was
identical. GitHub dismisses approvals on **any** force-push regardless of
content. The first approver had to re-approve on every unrelated commit
landing on `main`, indefinitely.

**Root cause:** the rebuild step always ran `git push --force` without checking
whether the new squash content differed from the existing promotion branch.

**Fix (actions#225):** tree-identity check before force-pushing:

```bash
NEW_TREE=$(git write-tree)
EXISTING_TREE=$(git rev-parse "origin/${PROMOTION_BRANCH}^{tree}" 2>/dev/null || echo "")
if [ "$NEW_TREE" = "$EXISTING_TREE" ] && [ -n "$EXISTING_TREE" ]; then
  echo "promoted=skipped"   # skip push — approvals preserved
else
  git commit && git push --force
  echo "promoted=true"      # content changed — new approval required (correct)
fi
```

`promoted=skipped` passes all downstream `!= 'false'` guards — PR body and
gate section still refresh. Only the push is skipped.

**Rule:** Never force-push a promotion branch when the squash tree is unchanged.
`git write-tree` before committing gives the tree hash of staged content without
creating a commit.

### Promotion PR: force-push clears reviewRequests — maintainers team not notified (2026-06-13)

After a force-push, GitHub clears all pending reviewer requests. `reviewRequests`
becomes `[]`. The team doesn't know re-review is needed; the PR sits blocked
with no active requests.

**Fix (actions#226):** re-request the maintainers team after any force-push:

```bash
if [ "${{ steps.rebuild.outputs.promoted }}" = "true" ]; then
  gh pr edit "$PR_NUMBER" \
    --add-reviewer "${{ github.repository_owner }}/maintainers" 2>/dev/null
fi
```

Skip on `promoted=skipped` — approvals are preserved so no re-request is
needed. Re-requesting when nothing changed would spam reviewers with no new
content to review.

**Both fixes are in `reusable-promote-squash.yml@v1`** and apply automatically
to bluefin, bluefin-lts, and dakota.

## buildah in export recipe — do not use without confirming availability

**Context:** `f8b80d4` switched the `just export` recipe from `podman build --squash-all` to
`buildah from + buildah mount + buildah commit` to save ~35–50 min by avoiding full image re-encode.

**Bug (dakota#841):** This broke two things:
1. **Boot failure on real hardware** — the multi-layer `buildah commit` output differs from the
   single flat layer produced by `--squash-all`. chunka's composefs xattr injection expects to
   rechunk a flat image; multi-layer input produces a different composefs tree that fails to mount
   at boot.
2. **Local/Argo builds broken** — `quay.io/podman/stable` (used by `just build` and the Argo
   `dakota-bst` WorkflowTemplate) does not include `buildah`. GitHub Actions ubuntu-24.04 has
   buildah pre-installed, so GHCR builds succeeded while local/Argo builds errored with
   `buildah: command not found` (exit 127).

**Fix:** Reverted to `podman build --squash-all` in PR fixing #841.

**Rule:** Any `just export` change that introduces a tool dependency beyond `podman` must be
verified in both environments:
- `quay.io/podman/stable:latest` (Argo pipeline image)
- `ubuntu-24.04` GitHub Actions runner
If the tool is only available on ubuntu-24.04, the Justfile recipe must install it explicitly
(e.g. `dnf install -y buildah`) or the approach must avoid it entirely.
