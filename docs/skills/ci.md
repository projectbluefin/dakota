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
| `.github/workflows/weekly-testing-promotion.yml` | Weekly promotion (Tue 06:00 UTC): verifies `:testing` digests, re-tags as `:latest` + `:stable`, fast-forwards branches. |
| `.github/workflows/e2e.yml` | Smoke test via projectbluefin/testsuite. Fires on PR when image-affecting paths change. |

## Trigger Behavior

| Behavior | pull_request | merge_group | schedule | workflow_dispatch |
|---|---|---|---|---|
| `validate` job | Yes | No | No | No |
| `e2e` job | Yes (path-filtered) | No | No | No |
| `build` job | No | Yes | Yes | Yes |
| Push to GHCR? | No | Via publish.yml | Via publish.yml | Via publish.yml |

**PR path:** `validate` + `e2e` (path-filtered) — zero remote execution. ~15 min cached, ~30 min cold.

**e2e path filter:** `e2e` fires only when `elements/`, `files/`, `patches/`, `Justfile`, or `project.conf` change. Skipped otherwise — skipped counts as passing for the required status check.

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

**e2e path filter:** `e2e` only fires for PRs touching `elements/`, `files/`, `patches/`, `Justfile`, or `project.conf`. For all other paths (e.g. workflow pin bumps) it is skipped, which satisfies the required check. Junction bumps in `elements/` always run e2e.

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

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`

### publish.yml startup_failure = :testing is stale (2026-06-04)

`startup_failure` on `publish.yml` nightly runs means the BST artifact or
CAS cache lookup failed before the job even started. When this happens on two
or more consecutive nights, `:testing` stops being updated. Symptoms visible
downstream: every dep-update PR shows "SSH never became ready" in e2e because
the QEMU VM tries to boot the stale image. Fix: investigate `publish.yml`
startup_failure first — check repo Secrets/Variables for `CASD_CLIENT_CERT`
and `CASD_CLIENT_KEY` expiry, and confirm the CAS server is reachable.

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
