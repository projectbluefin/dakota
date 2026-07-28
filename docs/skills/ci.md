---
name: ci
description: CI entry point for Dakota. Routes agents to the right CI skill fast: workflow map, GitHub Actions tooling failures, e2e/boot checks, release promotion, or merge-queue recovery. Use when the task mentions CI, Actions, publish, promote, release, smoke, boot-check, or startup_failure.
metadata:
  context7-sources:
    - /websites/github_en_actions
    - /websites/github_en_rest
    - /actions/cache
    - /bootc-dev/bootc
    - /apache/buildstream
---

# CI Router

## Overview

This is the **load-first** CI skill. Do not dump the whole CI history into context up front.
Load this file, identify the failure class, then load only the next skill you need.

## Dakota build model

**Target contract:** Dakota's four x86_64 image variants execute through the
BuildBox 1.4.11 CAS/executor at `cache.projectbluefin.io:11002`. The GitHub
runner drives BuildStream, but build actions and CAS payloads remain on the
remote host.

For Dakota, that means:
- one concurrent matrix job for each of default, NVIDIA, gaming, and NVIDIA-gaming;
- `max-parallel: 4`, matching the backend's four global action slots;
- `cache.storage-service` plus `remote-execution` execution, storage, and action-cache services;
- writable artifact/source remotes so BuildStream's build pipeline publishes results automatically;
- no explicit dependency pre-pull, standalone artifact push, seed shards, or local fallback;
- `build.max-jobs: 4` for the initial capacity setting.

The x86 build is fail-closed. Missing mTLS credentials, a missing RE block, an
unreachable executor, or an absent `Remote Execution Configuration` startup
banner fails the job. Fetch-only consumers such as `publish.yml` intentionally
omit top-level remote storage and RE because artifact checkout must materialize
the final image on that runner.

When the composite action generates BuildStream configuration, it writes
`buildstream-ci.conf` into `${GITHUB_WORKSPACE}`. The `just bst` wrapper mounts
the checkout at `/src`, making the file available as
`/src/buildstream-ci.conf` inside the bst2 container.

## When to Use

Use this skill when the task mentions:
- GitHub Actions failures
- `startup_failure`, `action_required`, missing jobs, or flaky checks
- `publish.yml`, `build.yml`, `execute-release.yml`
- boot-check, smoke, testsuite, SBOM, or GHCR publish problems
- merge queue, promotion PRs, or stable release flow

## When NOT to Use

- Element build or packaging failures inside BST → `debugging.md`
- BST syntax, element kinds, or project layout → `buildstream.md`
- OCI image contents or layer assembly → `oci-layers.md`
- Normal PR review → `pr-review.md`

## ⚠️ Builder Discipline — Read Before Doing Anything

**ONE BUILD WORKFLOW RUN at a time. Its four x86_64 variants run together.**

Before merging, pushing, or dispatching any workflow, run the mandatory pre-flight:

```bash
gh run list --repo projectbluefin/dakota --limit 30 \
  --json databaseId,status,name,headBranch \
  | python3 -c "
import json, sys
runs = json.load(sys.stdin)
active = [r for r in runs if r['status'] in ('in_progress', 'queued', 'pending', 'waiting')]
if active:
    print(f'BLOCKED: {len(active)} active run(s). Cancel all before proceeding:')
    for r in active:
        print(f'  gh run cancel {r[\"databaseId\"]} --repo projectbluefin/dakota  # {r[\"name\"]} [{r[\"headBranch\"]}]')
else:
    print('OK: field is clear')
"
```

If output is not `OK: field is clear` — **cancel every listed run first**.

**Cache-warm is not exempt.** Independent workflow runs still contend for the
same executor and CAS. The four matrix jobs within one x86 build are a single,
coordinated run: BuildBox caps them at four remote actions and their payloads
stay in the remote CAS. Never cancel or serialize those matrix siblings.

The rationalizations that have caused real production failures:
- "Cache-warm is additive, it helps the build" → **No. Cancel it.**
- "This is almost done, just a few minutes" → **Cancel it. You don't know that.**
- "It's a different branch, it won't interfere" → **Same runners and CAS. Cancel it.**
- "I cancelled one, that's enough" → **Cancel ALL. Re-run pre-flight.**

## Core Process

1. **Run the mandatory pre-flight above. Verify `OK: field is clear`.**
2. **Classify the failure before reading logs.**
   - *Which workflow?* `build`, `publish`, `promote`, `release`, `e2e`, `merge queue`
   - *Which phase?* trigger, setup, reusable workflow call, build/export, boot, smoke, promotion
3. **Load one next skill, not five.**
   - Need workflow/trigger map → `workflow-map.md`
   - Need reusable workflow / permissions / cache-dir weirdness → `ci-tooling.md`
   - Need boot-check / smoke / testsuite behavior → `e2e-ci.md`
   - Need `:testing` → `:stable` / release flow → `release-promotion.md`
   - Need stale PR or queue cleanup → `merge-queue.md`
3. **Read the actual workflow file before editing.**
4. **Verify tool behavior via Context7** for GitHub Actions or bootc when changing syntax/flags.
5. **Write back the lesson** to the narrowest skill file, not this router, unless the routing itself changed.

## Fresh publish verification for testing images

### Public GHCR visibility checks must not use runner credentials

Dakota's published images are public. The post-push `skopeo inspect` probe in
`publish.yml` must inspect the immutable SHA tag without `--creds`; GHCR can
reject the authenticated probe even while the public manifest is readable.
Keeping credentials on that probe makes the job fail before signing and leaves
an unsigned candidate that `execute-release.yml` correctly rejects.

For recovery, `publish.yml` accepts a `source_sha` workflow-dispatch input so a
fixed publisher can republish an existing remote-CAS artifact without starting
a new BuildStream build.

When the task is "publish a fresh testing image" or "why is the image date wrong", verify the live state before changing anything.

1. Start with the GitHub CLI: `gh run list --repo projectbluefin/dakota --limit 10` and `gh run view <run-id> --repo projectbluefin/dakota`.
2. Check both the build run and the follow-on publish run. A fresh build can be in progress while `ghcr.io/projectbluefin/dakota:testing` still points at the previous digest.
3. Confirm the tag moved with `skopeo inspect docker://ghcr.io/projectbluefin/dakota:testing` and inspect `org.opencontainers.image.created` plus `org.opencontainers.image.revision`.
4. If the tag still shows the old timestamp or revision, do not assume the publish completed. Wait for the publish workflow or inspect the latest successful publish run.

This is the fast path for stale-image complaints: the image date is usually wrong because the tag was not republished, not because the metadata formatter is broken.

## Skill Selection Table

| If the problem is about... | Load next |
|---|---|
| Which workflow owns this stage? | `workflow-map.md` |
| `startup_failure`, `jobs: []`, token scopes, reusable workflows | `ci-tooling.md` |
| `actions/cache`, podman bind mounts, runner/runtime quirks | `ci-tooling.md` |
| boot-check, QEMU, `bootc install to-disk`, smoke placement | `e2e-ci.md` |
| promotion PRs, release gate, `action_required`, stable release | `release-promotion.md` |
| conflicting chore PRs, stale queue branches | `merge-queue.md` |
| historical edge cases and deep cuts | `ci-reference.md` |

## Workflow Quick Reference

| Workflow | Trigger | What it does |
|---|---|---|
| `build.yml` | `push: testing` for key-busting paths, `workflow_dispatch`, `schedule: daily 13:00 UTC` — NOT `pull_request` or `merge_group` | Run default, NVIDIA, gaming, and NVIDIA-gaming concurrently through BuildBox; BuildStream publishes artifacts to the remote CAS and uploads logs. Does not push to GHCR. |
| `publish.yml` | `workflow_run` from `build.yml` (branches: testing, next, + their gh-readonly-queue/* paths) | Fetch the remote-CAS artifact, export to OCI, run `just lint`, push `:$sha`, sign/attest, and promote `:testing`/`:next` tags. No build happens here. |
| `execute-release.yml` | `workflow_run` from `publish.yml` on `testing`, `workflow_dispatch` | SHA freshness check (:testing vs :stable). If different: cosign verify → skopeo copy `:testing` → `:stable` → fast-forward main → create GitHub Release. Skips if equal. |
| `lab-check.yml` | `repository_dispatch: lab-check` from the Kubernetes lab | Uses a short-lived MergeRaptor installation token to create or update one `testing-lab / dakota` Check Run for the PR head SHA. It reports queued, running, and final BuildStream/QA details without posting PR comments. |
| `boot-test-aarch64.yml` | `workflow_run` from `build-aarch64.yml` on `testing`, `workflow_dispatch` (image input) | M0 aarch64 boot gate: verifies the `:aarch64` tag exists on GHCR (skopeo — does not trust build-aarch64's masked conclusion), boots it on `ubuntu-24.04-arm` via bcvk ephemeral (qemu/virtiofs, cargo-built — no upstream aarch64 binaries), gates on `multi-user.target`, reports graphical/gdm/bootc informationally, always uploads serial + journal artifacts. Never blocks x86_64. Tests direct kernel boot, not the bootc install-to-disk bootloader path. |
| ~~`promote-testing-to-main.yml`~~ | DELETED | Was: `push: testing`, schedule Tue 04:00 UTC, manual. |
| ~~`pr-release-gate.yml`~~ | DELETED | Was: `pull_request` to `main`. |
| ~~`sync-main-to-testing.yml`~~ | DELETED | Was: `push: main`. |
| ~~`cache-warm.yml`~~ | DELETED | Was: Mon/Thu 06:00 UTC schedule. Daily 13:00 UTC builds keep CAS warm. |

## Trigger Behavior

| Job | pull_request | push testing/next | merge_group | workflow_dispatch | schedule |
|---|---|---|---|---|---|
| `validate` | Yes | No | No | No | No |
| `e2e` | Yes (change-detected) | No | No | Yes | No |
| `build` | No | testing only (key-busting paths) | No | Yes | Daily 13:00 UTC |
| `execute-release` | No | No | No | Yes | Via workflow_run from publish |
| Push to GHCR? | No | Via publish.yml | No | Via publish.yml | Via publish.yml |

**push paths:** `build.yml` triggers on `testing` only when `elements/**`, `patches/**`, `project.conf`, or `include/**` changes. Doc/workflow-only pushes do NOT trigger a build. This is intentional; it means a CI-only commit advancing the branch HEAD will leave no build artifact for that SHA.

**Branch → tag mapping** (verified from publish.yml source):
- `testing` or `gh-readonly-queue/testing/*` → `:testing`
- `next` or `gh-readonly-queue/next/*` → `:next`

**PR path:** `validate` + `e2e` (change-detected) — no extra BuildStream warmup path. The default Dakota pipeline stays on a single assembly pass per target.

### Lab Check Run bridge

The lab reports Dakota PR validation through GitHub's Checks API, not PR
comments:

1. The lab creates the Argo workflow and dispatches a `lab-check` event with a
   nested, bounded payload.
2. `.github/workflows/lab-check.yml` mints a short-lived MergeRaptor
   installation token from the existing org secrets.
3. The workflow finds the latest `testing-lab / dakota` check owned by the
   `mergeraptor` app for that exact commit and updates it; it creates the check
   only when none exists.
4. Argo sends `queued`, `in_progress`, and `completed` updates. The final output
   includes the workflow parameters, pod/node placement, every workflow node,
   phase counts, timings, and failure messages.

Do not put the MergeRaptor private key in Kubernetes. The lab's existing GitHub
credential is used only to call `repository_dispatch`; GitHub Actions owns the
app-token exchange. Do not post a duplicate PR comment or commit status.

MergeRaptor must have repository `checks: write` and `contents: read`
permissions. The workflow uses contents access to validate the target commit
before updating its Check Run. GitHub's Checks endpoints require GitHub App
authentication; classic PATs and OAuth apps cannot update check runs.

> Source: `/websites/github_en_rest` — Checks runs and repository dispatch.

**e2e change detection:** `e2e` uses a `should-run` job that diffs the PR branch against its base. It runs when `elements/`, `files/`, `patches/`, `Justfile`, or `project.conf` change; otherwise the `e2e` job is skipped. Skipped satisfies the required status check.

**Merge queue path:** `build` is intentionally excluded from `merge_group`; queued PRs rely on the required validation/e2e checks, and the post-merge push to `testing` starts the real BuildStream path when key-busting files changed.

**Daily build schedule:** `build.yml` fires at 13:00 UTC daily (after `nightly-next-build` completes). This keeps the remote CAS warm and ensures a fresh `:testing` tag even without a code push. `cache-warm.yml` was deleted — the daily build replaces it.

**RE-backed assembly model:** `build.yml` starts all four x86 variants together.
Each invokes one final BuildStream target with remote storage, execution, and
action-cache services. BuildStream automatically queues artifact/source pushes
during the build; there is no warm-up pull or post-build push phase.

## Remote Cache Architecture

`cache.projectbluefin.io:11002` terminates mTLS in Traefik and forwards all REAPI
and Remote Asset traffic to one BuildBox 1.4.11 `buildbox-casd` instance. The
backend runs on a 32-thread Ryzen 9 7950X3D host with 128 GiB RAM and starts with
`--jobs 4`. This is a single BuildBox executor, not the historical BuildBarn
Kubernetes grid described by older lessons.

The build config deliberately contains both forms of storage service:

- top-level `cache.storage-service` keeps the runner's CAS remote-backed, avoiding
  full artifact pull/push payloads;
- nested `remote-execution.storage-service` supplies action inputs and outputs to
  the remote executor.

Publish/export configs must not contain the top-level storage service: checkout
needs the image's file blobs locally before podman can export and push to GHCR.

### mTLS Authentication

| Variable | Type | Content |
|---|---|---|
| `CASD_CLIENT_CERT` | Repository **variable** | PEM-encoded client certificate (public) |
| `CASD_CLIENT_KEY` | Repository **secret** | PEM-encoded private key |

The x86 build refuses to start RE unless both values are present. The generated
credential files are mode `0600`; only the non-secret config containing their
paths is copied into `logs/`.

## ⚠️ RE Fail-Fast Evidence

1. **Generated config contains remote storage and execution**

   ```bash
   grep -nE "^(cache:|remote-execution:|  storage-service:)" buildstream-ci.conf
   ```

   A build config needs one top-level and one nested `storage-service:` plus the
   `remote-execution:` block. The checked-in validator generates both build and
   fetch-only modes with dummy credentials and rejects drift.

2. **BuildStream startup reports `Remote Execution Configuration`**

   `build.yml` captures the console and fails the job if this startup section is
   missing, even when the requested artifact is already cached:

   ```bash
   grep -F "Remote Execution Configuration" logs/bst-console-*.log
   ```

3. **Uncached actions wait on the remote executor**

   A run that actually has cache misses should show:

   ```bash
   grep -F "Waiting for the remote build to complete" logs/bst-console-*.log
   ```

   A completely warm run may legitimately have no worker action to observe. In
   that case the generated configuration, startup banner, and successful remote
   cache initialization prove the fail-closed path was loaded; do not force a
   cache miss merely to create worker activity.

For host-side diagnosis, SSH to `ahmedadan@cache.projectbluefin.io` and inspect
`cache-buildbox-casd-1` with rootful podman. Do not use the superseded
`kubectl -n buildbarn` instructions.

## ⚠️ Pre-Commit BST Syntax Gate

For any change to `project.conf`, `*.bst` elements, or `Justfile`:

```bash
just bst show oci/bluefin.bst
```

Must exit clean before `git commit`. Catches invalid option names, types, and element references. Takes 5 seconds. Skipping wastes a 90-second CI build slot.

## ⚠️ Branch Base Rule

Always branch from `upstream/testing` (the development trunk), never from local `testing` or `main`:

```bash
git checkout upstream/testing -b feature/my-change
git diff upstream/testing...HEAD --stat   # verify before pushing
```

**Recovery when a branch is already dirty:**
```bash
git rebase --onto upstream/testing <last-unwanted-commit-sha> <branch-name>
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
| Build OOM or hangs | Worker memory pressure under RE, or a failed RE configuration | Verify the startup banner, then inspect the four-slot BuildBox host. Keep `max-jobs: 4` for the initial rollout. Prefer upstream GNOME OS / GBM / FSDK alignment over local compiler workarounds. Runner-local compilation is not a supported fallback. |
| "No space left on device" during **Chunkify** | Overlay copy-ups from `inject-xattrs.py` exhaust the ~1 GB root FS left by `setup-runner`'s BTRFS loopback | Fixed centrally in `chunka@v1` — auto-selects `/var/lib/containers` (BTRFS, ~49 GB) over `/var/tmp` (~1 GB) |
| "No space left on device" during **Build** | BST cache fills runner disk | Check if any element generates large buildtrees. With RE enabled, the runner should not be building elements locally; if it is, see the semi-cold RE cascade lesson below. |
| `bootc container lint` fails | Image structure issues | Check OCI assembly, `/usr/etc` merge |
| Build succeeds locally, fails in CI | Different cached versions or RE not enabled in CI | Compare `bst show` output; check remote CAS; confirm the CI generated config contains a `remote-execution:` block |
| GHCR push fails | Token permissions | Check `packages: write` permission |
| aarch64 push fails `localhost/dakota:aarch64: image not known` (exit 125) | `just export`/`just lint` tag `{image_name}:{image_tag}` from `BUILD_IMAGE_TAG` (default `latest`); `build-aarch64.yml` must set `BUILD_IMAGE_TAG: aarch64` at workflow env level or the push step's `dakota:aarch64` ref never exists | Fixed 2026-07 by adding `BUILD_IMAGE_TAG: aarch64` to workflow env. Beware: `build-aarch64.yml`'s job-level `continue-on-error: true` makes the run conclusion read `success` even when the job failed — check job conclusions, not run conclusions (`boot-test-aarch64.yml` verifies the tag exists via skopeo instead of trusting the conclusion). |
| Remote cache not used | Cert/key not configured or RE block missing | Check repo Variables and Secrets. Also verify the generated config contains both `remote-execution:` and the cache sections; cache credentials alone do not prove RE. |
| Cache-only / runner-local x86 build | Missing `remote-execution:` or `cache.storage-service`, missing credentials, or unreachable BuildBox backend | The generator and runtime banner checks fail closed. Diagnose the endpoint; do not add a local fallback. |

### Debugging Workflow

1. **Check config step output** — confirm the generated `buildstream-ci.conf` contains a `remote-execution:` block, not only `artifacts:` / `source-caches:` sections
2. **Search build log** — look for `[FAILURE]` lines; `on-error: continue` collects all failures
3. **Verify RE is active** — confirm BuildStream reports `Remote Execution Configuration`; on a cache miss, look for `Waiting for the remote build to complete`
4. **Check remote cache activity** — inspect pull/push metadata without expecting full payload transfers through the runner
5. **Reproduce locally only as a failure investigation** — `just bst build oci/bluefin.bst` uses the same bst2 container, but a local runner-only reproduction is for diagnosing a specific RE failure, not for bypassing RE in CI

## Generated Files (Pre-Commit Required)

Some files are generated locally and committed. Generation requires `bst artifact list-contents`, which can read from a configured remote artifact cache, but running the generator is still a local pre-commit step. Do not treat CI's ability to read remote artifacts as a reason to defer regeneration.

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

### testing (development trunk)

Ruleset: `testing-merge-queue-no-review`

| Rule | Value |
|---|---|
| Required reviews | 0 (fully automated) |
| Required status checks | `validate` + `e2e` |
| Merge queue | enabled (SQUASH, ALLGREEN) |
| Force push | blocked |
| Deletion | blocked |

**`testing` is the GitHub default branch and the merge target for all PRs.**

### main (release bookmark)

Ruleset: `main-bookmark-protection`

| Rule | Value |
|---|---|
| Required reviews | none |
| Required status checks | none |
| Merge queue | none |
| Non-fast-forward | blocked |
| Deletion | blocked |

`main` is written only by `execute-release.yml` via fast-forward after each successful stable promotion.

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

> **Note:** Lessons are ordered newest-first. Deleted CI paths are historical evidence only; do not recreate them.

### Remote-backed CAS removes runner transfer phases (2026-07-28)

The production endpoint is a single BuildBox 1.4.11 `buildbox-casd` executor
behind Traefik mTLS, not the historical BuildBarn cluster. It has four action
slots on a 32-thread, 128 GiB host. Match that capacity with four concurrent
variant jobs and start conservatively at `build.max-jobs: 4` per action.

BuildStream 2.7 distinguishes artifact remotes, remote execution storage, and
the top-level cache storage service. A `remote-execution:` block alone still
leaves the runner's CAS local. Adding `cache.storage-service` makes that CAS
remote-backed: directory metadata is available locally while file payloads stay
on the BuildBox host. Because the writable artifact/source remotes use the same
CAS, BuildStream's automatic push queues publish metadata and deduplicate blobs
without a separate `bst artifact push` transfer.

Use the top-level storage service only for build jobs. Publish/export and
filemap generation need local file materialization and must use fetch-only
configs without it. The generated config tests enforce both modes, credential
fail-closed behavior, and composite shell syntax.

### Architecture options must match upstream artifact producers (2026-07-13)

BuildStream project options participate in artifact cache keys. Passing
`-o x86_64_v3 true` to an otherwise upstream-aligned graph therefore cannot
reuse baseline x86-64 artifacts published by GNOME Build Meta or
freedesktop-sdk. Historical Dakota v3 successes depended on warm artifacts in
`cache.projectbluefin.io`, not the upstream caches: the June 30 default build
pulled 810 artifacts from the project cache, while identical sampled v3 keys
were absent from every remote by July 13. Direct probes of `gettext`, `expat`,
and `startup-notification` found each v3 key missing and each baseline key
available. A full baseline pull produced 978 cached elements out of the 1,077
element default graph, compared with 73 remote hits in the failed v3 CI run.

Keep the standard local, build, validation, export, push, and SBOM paths on
`-o x86_64_v3 false`. The project option remains available for an explicit
local opt-in, but an opt-in v3 build must expect to compile and maintain its own
architecture-specific artifacts rather than relying on upstream cache reuse.
### Verified remote execution is required — runner-local/cache-only are unacceptable operational states (2026-07-19)

> The original lesson named a BuildBarn grid and described the then-disabled
> workflow. The backend and implementation details are superseded by the
> 2026-07-28 BuildBox lesson above; the fail-closed policy remains.

Normal x86 builds require the generated remote storage/execution configuration
and the BuildStream startup banner. Remote artifact/source access without RE,
or a local compilation fallback after RE failure, is not an acceptable
production state.

### Breaking Cold-Cache Starvation Loops via Temporary Timeout Extension (2026-07-13)

**The Failure Pattern (Cold-Cache Starvation):** When local patches or junction modifications (such as necessary changes to `freedesktop-sdk.bst`) intentionally alter build configuration or bootstrap elements, they inevitably change the cache keys for downstream elements. On the next CI run, a massive cache miss is triggered. With RE enabled, BuildBarn workers compile the uncached elements. If RE is broken and the runner falls back to local compilation, strict step/job timeouts (like 30m/45m) can abort the runner before it finishes, the `Push OCI artifact` step is never reached, and the remote CAS remains cold. Every subsequent CI run then hits the same timeout, resulting in a permanent cold-cache starvation loop.

**Why it happens:** The remote CAS can only be warmed up when a build successfully completes its compilation and reaches the `Push OCI artifact` step. Protective timeouts prevent wasteful multi-hour runner hangs, but they also block recovery if the runner is forced to compile locally because RE is unavailable.

**The Recovery Rule:**
1. **Differentiate intentional drift from accidental drift:** If the cache miss is due to a legitimate, intentional modification, expect BuildBarn workers to compile the changed elements. Do not panic.
2. **Verify RE is actually active first:** Use the RE fail-fast evidence checks above. A run that is compiling locally on the runner is in a failure state regardless of timeouts.
3. **If RE is verified healthy but the build still times out:** temporarily extend workflow timeouts to let BuildBarn finish the cold compile and the push step. Raise the GHA build step timeout (e.g., to 90 minutes) and the job timeout (e.g., to 150 minutes).
4. **If RE is not healthy, this is a diagnosed failure investigation:** a temporary runner-local compile with extended timeouts may be used to warm the CAS, but the resulting PR must also restore RE before it is merged. Runner-local builds are not an acceptable steady state.
5. **Revert back to protective defaults:** Once RE is restored and subsequent builds are confirmed to finish in under 5 minutes, immediately revert the workflow timeouts back to the safe 30m/45m defaults.

### Cache-Only Assembly and the Build-From-Source Trap (2026-07-12)

> **Superseded by the RE-first policy.** The original lesson described a cache-only / runner-local assembly model. Dakota now requires verified remote execution. Retain the core principle (align to warm caches, do not let the runner compile the world) but route compile work to BuildBarn, not the runner.

**The Repetitive Failure Pattern:** When encountering a dependency cache miss during final OCI assembly, agents are prone to panic, remove the `--deps none` constraint from `build.yml`, and increase the workflow step timeouts to 330+ minutes. This triggers the *Build-From-Source Trap* where the GHA runner attempts to compile heavy bootstrap packages (like `gcc` and `glibc`) from source, resulting in extremely slow multi-hour builds that ultimately fail or time out.

**Why it happens:** The cache miss is typically caused by local element, patch, or junction modifications that deviate from the known-good cache keys stored on the remote CAS. Allowing source compilation on the runner or raising timeouts merely papers over the key drift and violates the RE-first operating model.

**The Self-Improvement Fix:**
1. **Never build from source on the runner:** With RE enabled, BuildBarn compiles uncached elements. The runner must not be the compile host. If the runner is compiling heavy packages, RE has failed; diagnose and restore RE.
2. **Keep `--deps none` for the final OCI assembly step:** `just bst build --deps none ${{ matrix.element }}` still keeps the runner from pulling the full dependency graph, but the RE config must still be present so any missing artifacts are built remotely, not locally.
3. **Pre-warm cold caches only as a local aid:** Running `just bst artifact pull --deps all ${{ matrix.element }}` can pre-pull prebuilt artifacts into the local GHA runner cache in ~2 minutes, but this is an optimization, not a substitute for RE. A run that only pre-pulls and then builds locally is cache-only and unacceptable.
4. **Keep timeouts tight:** Enforce a strict 30-minute step timeout and 45-minute job timeout. If a cache miss occurs, the build must fail fast and loudly unless RE is verified active and the cold compile is genuinely progressing on BuildBarn workers.
5. **Align, do not compile locally:** When a build fails due to a cache miss, the primary fix is still to align the elements, patches, and files to the known-good baseline to restore 100% warm-cache keys. Do not touch workflow timeouts or dependency flags to hide a runner-local compile. If alignment is impossible, use verified RE to compile the cold elements; runner-local compilation is a diagnosed-failure fallback only.

### Runner cache configuration must preserve upstream fallbacks (2026-07-11)

The normal path is a BuildStream build per target routed through the BuildBox
executor at `cache.projectbluefin.io:11002`. That endpoint is the authenticated
writable cache; `gbm.gnome.org:11003` and `cache.freedesktop-sdk.io:11001` must
remain read-only artifact/source fallbacks. Replacing the server list forces a
cold SDK and GNOME compile. The config is written under `${GITHUB_WORKSPACE}`
because the `just bst` container maps it to `/src`. Do not recreate seed shards,
pre-pulls, retry chains, standalone push tails, or local publish fallbacks.

### Publishing is the deliverable — local full-image builds are never a push gate (2026-07-09)

An agent session extended a 10-day `:testing` outage to 11 days by gating the push of already-validated fixes on a full local image build (8+ hours, two WebKit variants). The fixes had sufficient targeted evidence hours earlier: the previously-failing element (mutter) compiled past its failure point, the graph was frei0r-free, `just patch-drift-check` and actionlint were green, and cache realignment was confirmed by the cached-element count jump. That is what "test evidence before push" means — targeted validation of the changed behavior. CI performs the full-image verification itself; duplicating it locally before pushing adds nothing and delays the publish by the length of the build. When `:testing` is stale, treat pushing the fix as the primary deliverable and local work as evidence-gathering only.

### CI pre-flight cancel-then-push is one atomic sequence (2026-07-09)

The pre-flight rule (cancel all active runs before any CI action) has a failure mode: cancelling the in-flight daily build and then NOT completing the push — for example because the turn ended while a cancellation was still draining. Net effect is strictly worse than doing nothing: the existing build dies and no replacement is queued. Cancel → verify field clear → push/dispatch must complete in one uninterrupted sequence. If you cannot finish the push in the same working block, do not start cancelling.

### The graph has 100% cache alignment — WebKit compilation is eliminated (2026-07-11)

Applying any patches to the `gnome-build-meta` junction (e.g., local patch queues) invalidates cache keys for downstream elements and forces hours of WebKit compilation from source. In July 2026, the local patch queue was completely removed from `elements/gnome-build-meta.bst` (commit `dbb9f6d6`). This restores 100% cache alignment with `gbm.gnome.org:11003`. WebKit and other platform elements are now fetched as cached artifacts. DO NOT introduce any local patches to gnome-build-meta or freedesktop-sdk junctions, as this forces WebKit recompilation. DO NOT run any WebKit compilation or seed shards in CI workflows, as they are completely unnecessary and slow down the publish pipeline.

### RE-backed BST builds route compile work off the runner (2026-07-11)

> Backend and configuration details are superseded by the 2026-07-28 lesson.

The durable rule is that `just bst build ...` loads a `remote-execution:` block
and does not silently fall back to local compilation. The current BuildBox host
provides the RE frontend and cache services. Keep `scheduler.builders: 2` and
start at `build.max-jobs: 4`; backend `--jobs 4` caps global action concurrency.
The only generated file used by the build is `/src/buildstream-ci.conf`.

### Cache access and RE are separate; verify both (2026-07-11)

> **Superseded by the RE-first policy.** The original lesson treated runner-local execution as the working path and remote cache as a separate service. Dakota now requires remote execution; cache access alone is insufficient.

Cache access and remote execution are distinct concerns in BuildStream:

- `artifacts:` / `source-caches:` make the runner talk to `cache.projectbluefin.io:11002` for pulls and pushes.
- `cache.storage-service` keeps CAS file payloads off the runner.
- `remote-execution:` routes actual build actions to BuildBox.

The required evidence is the generated remote-backed config and BuildStream's
`Remote Execution Configuration` startup banner. On cache misses, logs also show
remote action waits; fully cached runs do not need to manufacture one.

A config with cache sections but no `remote-execution:` block puts the build into cache-only / runner-local mode. That is an unacceptable operational state and must be treated as a bug, not a working fallback.

Next-run checklist for any future build-path investigation:

```bash
# 1. Confirm the generated config contains remote execution
grep -n "remote-execution:" buildstream-ci.conf

# 2. Confirm the generated config includes the remote cache sections
grep -n "cache.projectbluefin.io:11002" buildstream-ci.conf

# 3. Check BuildStream startup for the RE configuration banner
grep -A5 "Remote Execution Configuration" logs/*/*.log

# 4. Check the build logs for worker-executed actions
grep "Waiting for the remote build to complete" logs/*/*.log | tail -50
```

### ARM warm-cache must be a parallel job with its own concurrency group (2026-06-22)

The `cache-warm.yml` originally had only an x86_64 job. Adding ARM as a second
step inside the same job would serialise the two architectures and block x86 on
ARM failures. The correct pattern:

- Add a **second top-level job** (`warm-cache-aarch64`) — no `needs:` dependency.
- Use a **separate `concurrency.group`** (`dakota-cache-warm-aarch64`) so the two
  jobs never queue behind each other.
- Set `continue-on-error: true` on the ARM job — ARM failures never block x86.
- Use `BST_FLAGS: --no-interactive --config /src/buildstream-ci.conf --option arch aarch64`
  — the `--config` flag is required for the generated BST CI config (and the
  remote CAS push) to actually take effect.
- Use the same RE-first config as x86_64 (`enable-remote-execution: 'true'`) — any ARM build must also route compile actions to BuildBarn. If ARM RE is genuinely not available, that is a diagnosed infrastructure gap to fix, not a reason to default ARM to runner-local/cache-only execution.
- Use a distinct BST workspace cache key: `bst-warm-aarch64-${{ hashFiles(...) }}`
  — sharing a key with x86 will cause cross-arch cache pollution.

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

### Do not paper over real build failures with workflow timeout changes (2026-07-05)

If `Build OCI image with BuildStream` dies exactly at the step timeout while still
advancing the element graph, do not assume the timeout is the root cause. Check the
build logs first: a CAS blob mismatch or other real build failure can look like a
slow run until the step hits its limit.

For this failure path, the correct fix is in the OCI layer bytes (for example
`elements/oci/bluefin.bst`), not in the workflow timeout budget. Changing the
workflow only hides the symptom and leaves the underlying artifact issue in place.

### `oci/bluefin.bst` CAS digest mismatch workaround must change layer bytes (2026-07-04)

When a build fails during pull with:
`Failed to download blob <digest>: 13` and CASD reports:

`Expected blob with digest <A>/<size>, but downloaded blob has digest <B>/<size>`

the issue is a poisoned remote blob object, not a build timeout. A no-op command
(`true`) only changes the element key and can still resolve to the same poisoned
layer blob digest if output bytes are unchanged.

**Required workaround:** change deterministic layer content in `oci/bluefin.bst`
(for example a stable `cas-epoch` marker file under `/usr/lib/projectbluefin`) so
the produced layer blob digest changes and bypasses the bad remote object.

**Concrete fix (commit 9001b98b):** Replace no-op `- true` with:
```yaml
- |
  install -d /layer/usr/lib/projectbluefin
  printf '%s\n' 'cas-epoch-2026-07-04-1' > /layer/usr/lib/projectbluefin/cas-epoch
```

This writes deterministic content that changes layer output bytes. BuildStream hashes
the layer artifact, produces a new blob digest, and avoids the poisoned remote blob
at the old digest/size tuple. The `cas-epoch-YYYY-MM-DD-N` naming lets future fixes
be identifiable by timestamp and attempt number.

### `oci/bluefin.bst` CAS digest mismatch requires changing layer bytes (2026-07-04)

A no-op cache-bust such as `- true` is not sufficient for this element. BuildStream
can still reuse the same CAS layer blob if the produced layer bytes are unchanged,
so the poisoned remote object is hit again. The verified fix is to write a small,
deterministic marker file into the layer, e.g. `/usr/lib/projectbluefin/cas-epoch`.
That changes the layer bytes, forces a new blob digest, and avoids the bad remote
blob object. This was verified locally with `just bst build --deps none oci/bluefin.bst`.

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

`check-diff` compares `dakota:testing` vs `dakota:stable` only. If they match,
`has_diff=false` and the entire `promote` matrix is skipped — including the
nvidia variant. This means if `dakota-nvidia:stable` was never created (e.g.,
nvidia `:testing` didn't exist during the first promotion that set `:stable`),
it will silently never get set on subsequent runs where the default image hasn't
changed.

**How it breaks:**

1. First promotion: NVIDIA `:testing` not found → `has_nvidia=false` → nvidia skipped
2. Next promotion: NVIDIA `:testing` now exists, but `dakota:testing == dakota:stable`
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
setup → publish-image → boot-check → promote   (critical path to :testing: ~46 min)
              ├──────→ smoke                    (observational, ~90 min, does NOT block promote)
              └──────→ publish-sbom             (runs in parallel, does NOT block promote)
```

**Job renames / splits:**
- `publish` renamed to `publish-image` — exports OCI, pushes `:$sha`, signs. No SBOM.
- `publish-sbom` (new) — depends on `publish-image`, runs in parallel with `promote`.
  Contains: SBOM generation, artifact upload, oras attach, cosign sign SBOM.
- `promote` — depends on `[setup, publish-image, boot-check]` only. Neither SBOM nor smoke are in `needs`.

**Critical:** Do NOT add `smoke` to `promote.needs`. Smoke is observational (~90 min) and was previously
blocking promote despite the `if:` condition allowing pass or fail. Removing it from `needs` saves ~85 min
on the critical path to `:testing`. Fixed 2026-06-16 (#890).

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

### chunka overlay dirs must land on BTRFS, not root FS (2026-06-13)

**Symptom:** `Chunkify image layers` step fails with:
```
No space left on device
```
The GitHub Actions runner terminates mid-step with a `System.IO.IOException` in the
runner diagnostic log. The step is killed before `sudo umount` can run, leaving
orphaned overlay mounts (cleaned up when the ephemeral runner terminates).

**Root cause:** `chunka@v1` (BST path) creates three overlay work dirs — `UPPER`,
`WORK`, `MERGED` — in `/var/tmp`. `setup-runner` mounts a BTRFS loopback over
`/var/lib/containers` using `loopback-free: "1"`, leaving only ~1 GB free on the
root filesystem. `inject-xattrs.py` sets `user.component` xattrs on every path in
`files/fakecap-manifest.tsv` (700K+ entries). Each `setxattr` call on a regular
file in an overlayfs triggers a **copy-up**: the entire file is copied to `UPPER`.
Copy-ups from a full OS image easily exceed 1 GB, exhausting the root FS.

**Fix (2026-06-13):** Fixed centrally in `projectbluefin/actions` `chunka@v1`
(`bootc-build/chunka/action.yml`). At runtime, the action now picks the directory
with the most free space from `[/var/lib/containers, /var/tmp]`:

```bash
_OVERLAY_TMPDIR="/var/tmp"
for _candidate in /var/lib/containers /var/tmp; do
  if [[ -d "$_candidate" ]]; then
    _free=$(df --output=avail "$_candidate" 2>/dev/null | tail -1 || echo 0)
    _best=$(df --output=avail "$_OVERLAY_TMPDIR" 2>/dev/null | tail -1 || echo 0)
    if (( _free > _best )); then _OVERLAY_TMPDIR="$_candidate"; fi
  fi
done
UPPER=$(mktemp -d -p "$_OVERLAY_TMPDIR")
WORK=$(mktemp -d -p "$_OVERLAY_TMPDIR")
MERGED=$(mktemp -d -p "$_OVERLAY_TMPDIR")
```

On CI runners with `setup-runner btrfs`, `/var/lib/containers` wins (~49 GB).
On local dev machines `/var/tmp` is the fallback. The action also logs the chosen
dir and available space for future diagnosis.

The same fix was applied to the `chunkify` recipe in the dakota `Justfile`
(used by `just build` for local dev).

**The fix is in `@v1` — no dakota workflow changes required.** All callers of
`chunka@v1` (default and nvidia variants across all branches) get the fix
automatically.

**Do not add a `/var/tmp` bind-mount workaround to individual workflows.** The fix
belongs in the action, not scattered across consumers.

### Dakota BST chunkify must use the compiled fakecap helper

The shared `chunka@v1` action's BST path injects every entry in
`files/fakecap-manifest.tsv` with Python. Dakota's manifest is approximately one
million entries, so the two `setxattr()` calls per entry make the publish stage
unacceptably slow even when the overlay is on the correct BTRFS volume. Dakota's
`Justfile` already has the equivalent compiled `fakecap-restore` helper; publish
uses that recipe and then transfers the rootful result back to the runner user's
podman store before lint and push.

### actions/cache does not create the cache directory on a cold miss — podman bind-mounts fail (2026-06-13)

`actions/cache` only *restores* an existing archive; on a cache miss it does
nothing and leaves the target path absent. If a subsequent `podman run` uses
bind mounts such as `-v "${HOME}/.cache/pip:/root/.cache/pip:rw"` or
`-v "${HOME}/.cache/buildstream:/root/.cache/buildstream:rw"` and the host-side
directory does not exist, podman exits **125** (container failed to start)
before any command runs.

```
Error: statfs /home/runner/.cache/buildstream: no such file or directory
error: recipe `sbom` failed with exit code 125
```

**Fix:** `mkdir -p` every host cache directory in the Justfile recipe
immediately before the `podman run`, not in the workflow step. This makes the
fix unconditional regardless of where `just sbom` is invoked:

```bash
mkdir -p "${HOME}/.cache/buildstream" "${HOME}/.cache/pip"
podman run --rm ... \
  -v "${HOME}/.cache/buildstream:/root/.cache/buildstream:rw" \
  -v "${HOME}/.cache/pip:/root/.cache/pip:rw" ...
```

**Rule:** Any `podman run -v HOST_PATH:...` where `HOST_PATH` is a cache
directory that may not pre-exist must be preceded by `mkdir -p HOST_PATH`.
Never rely on `actions/cache` to guarantee the directory exists.

### Boot-check gate: inline QEMU boot vs AT-SPI smoke (2026-06-13)

The testsuite `smoke` suite runs AT-SPI / GNOME Settings accessibility
tests that take **80+ minutes** in a VM and fail on timing sensitivity
in VMs, not on real image defects. Using it as a hard promote gate
blocks `:testing` on every merge without catching real regressions
(boot failures, composefs xattr breakage are caught by user reports,
not AT-SPI tests).

**Fixed in PR #849 / closes #850:**

`publish.yml` now has two separate jobs:

| Job | Gate type | What it checks | Target time |
|---|---|---|---|
| `boot-check` | **Hard** — blocks promote | bootc install → boot → SSH → GDM not-failed | ~10 min |
| `smoke` | Observational | Full testsuite smoke suite (AT-SPI etc.) | ~80 min |

The `promote` job gates on `boot-check.result == 'success'`. Smoke
runs in parallel for signal and does NOT appear in `promote.needs` —
removing it from `needs` is what makes it truly non-blocking (an `if:`
condition alone is insufficient; the job still waits if the dep is in `needs`).

**Rule:** The per-merge gate should always be a deterministic boot
check (SSH reachable + GDM not-crashed). The full AT-SPI suite belongs
in the weekly pre-stable gate, not the per-merge pre-testing gate.

**GDM headless caveat:** QEMU runs with `-display none` (no display
device). GDM will be `inactive` in this environment — that is expected
behavior, not a regression. The health check uses
`systemctl show gdm.service --property=ActiveState` and fails only if
the state is `failed` (GDM crashed). `inactive` / `activating` are
both acceptable. Using `systemctl is-active gdm.service` was wrong:
it exits 3 on `inactive`, which triggers `set -e` and blocks every
promote run regardless of image health.

### Observational reusable-workflow jobs must be split out of publish.yml (2026-06-16)

`continue-on-error` is **not** supported on jobs that call a reusable workflow
via `uses:`. That means an observational suite like `smoke` still makes the
parent workflow red if it lives inside `publish.yml`, even when `promote` no
longer depends on it.

**Symptom:** publish pipeline lands `:testing` successfully, but
`Publish Bluefin dakota` still ends red because the observational smoke job
fails inside the same workflow run.

**Fix:** move observational reusable-workflow jobs into a separate workflow
triggered by `workflow_run` from the successful publish pipeline. Keep the
hard gate (`boot-check`) in `publish.yml`; keep the flaky/slow signal in the
follow-up workflow.

**Rule:** If a GitHub Actions job is both (a) observational and
(b) implemented as a reusable-workflow call, it does not belong in the
critical publish workflow.

### OSTREE_PATH in boot-check kernel args must come from the BLS entry (2026-06-13)

When constructing QEMU kernel args for an inline boot check, the
`ostree=` kernel argument requires the path in the format:

```
/ostree/boot.1/default/TREEHASH/N
```

where `TREEHASH` is the **ostree commit SHA** — a completely different
hash from the deploy directory name (`/ostree/deploy/default/deploy/SHA.N`).
Using the deploy directory path as the ostree= argument causes the initrd
to fail to switch-root and the VM hangs silently.

**Fix:** Read the exact path from the BLS (Boot Loader Specification)
entry on the boot partition (p2). The entry already contains the correct
`ostree=` value that the real bootloader would use:

```bash
sudo mkdir -p /mnt_boot
sudo mount "${LOOP}p2" /mnt_boot
OSTREE_PATH=$(sudo grep -rh '^options' /mnt_boot/loader/entries/*.conf 2>/dev/null \
  | grep -o 'ostree=[^ ]*' | head -1 | sed 's/ostree=//')
sudo umount /mnt_boot
```

**Also:** always detach the loopback device after unmounting the image
before handing `disk.raw` to QEMU. Export the loop device name as a step
output and run `sudo losetup -d "${LOOP}"` after `umount`. Leaving the loop
device attached while QEMU holds the file open is a resource leak.

**Disk partition layout from bootc (systemd-boot, x86-64):**
- p1 = BIOS boot (1 MiB, grub fallback — no filesystem)
- p2 = EFI System / xbootldr (512 MiB, FAT32, BLS entries at `loader/entries/*.conf`)
- p3 = Linux root (xfs, ostree deployments live here)

Mount p2 to read BLS entries (it is the EFI partition, not a separate `/boot`).
Mount p3 to find the ostree deployment directory.

### `testing` branch divergence breaks `Sync main → testing` permanently (2026-06-14)

`reusable-sync-branches.yml` uses `git merge`. When `testing` has commits
`main` doesn't (diverged), the merge exits 1 and **every subsequent push to
`main` re-triggers the same failure** — the pipeline is stuck until a human
manually resets `testing`.

**How divergence happens:** Renovate PRs land on `testing` (digest bumps) while
human PRs land on `main` touching the same files (`publish.yml`, `Justfile`).
The two branches accumulate incompatible histories on the same paths.

**Emergency reset (API — no local clone needed):**
```bash
MAIN_SHA=$(gh api repos/projectbluefin/dakota/branches/main --jq '.commit.sha')
gh api repos/projectbluefin/dakota/git/refs/heads/testing \
  -X PATCH --field sha="$MAIN_SHA" --field force=true
```

**Systemic fix:** `projectbluefin/actions` PR #237 adds divergence detection to
`reusable-sync-branches.yml`. When `ahead > 0`, force-reset instead of merge:
```bash
AHEAD=$(git rev-list --count "origin/main..origin/testing")
if [ "$AHEAD" -gt 0 ]; then
  git reset --hard origin/main && git push --force origin testing
else
  git merge origin/main ...
fi
```
Safe: all testing-only commits are Renovate digests that Renovate recreates automatically.

**Diagnosis commands:**
```bash
# Check branch status
gh api repos/projectbluefin/dakota/compare/testing...main \
  --jq '{ahead_by:.ahead_by, behind_by:.behind_by, status:.status}'
# List last sync run results
gh run list --repo projectbluefin/dakota \
  --workflow 'Sync main → testing' --limit 5 \
  --json conclusion,displayTitle --jq '.[] | "\(.conclusion) \(.displayTitle[:50])"'
```

### `pr-triage.yml` approval said "auto-merge eligible" but never enabled it (2026-06-14)

The `Approved — clear label` step removed `pr/needs-review` and posted
_"Auto-merge is now eligible"_ but **never called `gh pr merge --auto`**.
PRs sat approved indefinitely.

**Fixed in PR #858:**
1. After approval: `gh pr merge "$PR_URL" --auto --squash`
2. After approval: `gh pr update-branch "$PR_URL"` (brings branch current so CI runs)
3. New `pr-autoupdate.yml` fires on every push to `main`, calls `gh pr update-branch`
   on all `BEHIND` PRs targeting main (skips Renovate/Mergeraptor bots)

**Also required:** `validate` must be in branch protection required status checks
so `--auto` waits for CI before merging, not just for review approval.

```bash
# Add validate as required check (branch protection API)
gh api repos/projectbluefin/dakota/branches/main/protection \
  --method PUT \
  --input - << 'JSON'
{
  "required_status_checks": {"strict": false, "checks": [{"context": "validate", "app_id": -1}]},
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true, "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null
}
JSON
```

**Rule:** never post "auto-merge is eligible" in a comment without also calling
`gh pr merge --auto`. The comment is a lie otherwise.

### `bootc install to-disk --via-loopback` fails with "No root filesystem specified" (2026-06-14)

Newer bootc no longer defaults the root filesystem type. Without
`[install.filesystem.root] type = "xfs"` in the image's install config,
`bootc install to-disk` exits 1 with `error: Installing to disk: No root
filesystem specified`.

**Fix:** add to `files/bootc-install/00-defaults.toml`:
```toml
[install.filesystem.root]
type = "xfs"
```

No behaviour change for users — xfs was always the implicit default. This makes it explicit.

### `bootc install to-disk` correct approach for CI loop devices (2026-06-17)

**Use `--via-loopback` with the raw file path, and let the image's own bootc
install config provide the xfs rootfs + systemd bootloader defaults.**

Working reference: `projectbluefin/testsuite/.github/actions/gnome-e2e/action.yml`
Source docs: https://github.com/bootc-dev/bootc/blob/main/docs/src/bootc-install.md

```bash
fallocate -l 30G disk.raw

sudo podman run --rm --privileged --pid=host \
  --security-opt label=type:unconfined_t \
  -v /dev:/dev \
  -v /var/lib/containers:/var/lib/containers \
  -v "$(pwd):/data" \
  "${IMAGE}" bootc install to-disk \
    --via-loopback /data/disk.raw \
    --wipe \
  || echo "bootc install exited $? (bootupd expected — continuing)"

# After container exits, attach with -P so the kernel scans the partition
# table and creates loop0p1/p2/p3 nodes on the host.
LOOP=$(sudo losetup -f --show -P disk.raw)
echo "BOOT_CHECK_LOOP=${LOOP}" >> "$GITHUB_ENV"
sudo udevadm settle --timeout=30 2>/dev/null || true

if ! sudo blkid "${LOOP}p3" &>/dev/null; then
  echo "ERROR: bootc install did not create a filesystem on ${LOOP}p3"
  sudo fdisk -l "${LOOP}" 2>&1 || true
  exit 1
fi
```

Dakota already ships the real install defaults in `files/bootc-install/00-defaults.toml`:

```toml
[install]
bootloader = "systemd"

[install.filesystem.root]
type = "xfs"
```

**Why this shape matters:** `--via-loopback` keeps bootc in control of the loop
lifecycle, avoiding host-side partition-node races. But the workflow should not
re-specify `--generic-image` or `--filesystem xfs` ad hoc — that drifted away
from the working testsuite flow and reintroduced `Creating rootfs: No such file
or directory (os error 2)` in Dakota publish boot-checks on 2026-06-17.

**Do NOT:**
- Pre-create a host loop device and pass it as a block device path — bootc's
  internal `sfdisk` + `mkfs` races the host udevd, causing `ENOENT` on p3.
- Use `--wipe` with a pre-created host loop — wipes the partition table,
  removing the nodes you just created.
- Pre-partition with `sfdisk` before running bootc — bootc refuses with
  "Detected existing partitions".
- Add `--generic-image` or `--filesystem xfs` back into the CI boot-check
  command; Dakota already gets xfs/systemd from image install config.

**Note:** The boot-check gate never passed from PR #849 (2026-06-13) through
PR #895 (2026-06-16) due to iterating on the wrong approach. The first stable
shape was `--via-loopback`; the 2026-06-17 regression came from drifting away
from the working testsuite invocation, not from a need to go back to host-side
loop handling.

### `multi-user.target` timing race in boot-check (2026-06-19)

**Symptom:** boot-check fails immediately after SSH becomes reachable with
`exit code 3` from `systemctl is-active multi-user.target`, even though the
image boots and SSH works.

**Cause:** `systemctl is-active` exits 3 for both `inactive` and `activating`.
SSH becomes reachable (sshd started) while systemd is still processing the rest
of `multi-user.target`'s dependency graph. The check fires before the target
finishes activating.

**Fix:** Replace the single `is-active` call with a retry loop:

```bash
for _i in $(seq 1 6); do
  if "${SSH[@]}" sudo systemctl is-active multi-user.target 2>/dev/null; then
    break
  fi
  [[ ${_i} -lt 6 ]] || { echo "ERROR: multi-user.target not active after 60s"; exit 1; }
  echo "  not yet active (attempt ${_i}/6), retrying in 10s…"
  sleep 10
done
```

**Log trap:** The GHA log interleaves the step's script preview with its output.
In a failed boot-check run, lines showing `is-active gdm.service` in the preview
column appear alongside `inactive` + `exit code 3` in the output column — making
it look like GDM failed. The actual failing line is always
`systemctl is-active multi-user.target` immediately above. Verify by checking
which `==>` echo precedes the `inactive` output, not which command appears in the
script preview.

---

### Mergeraptor merges on `next` do not fire `push` events (2026-06-19)

**Symptom:** Junction-bump PRs merge into `next` but `build.yml` never triggers.
The branch can go days without a build despite multiple commits landing.

**Cause:** Mergeraptor uses the GitHub API to merge PRs. Those merges do not
create a `push` event that triggers GitHub Actions workflows.

**Fix:** Add a scheduled dispatcher workflow (`nightly-next-build.yml`) that
calls `gh workflow run build.yml --ref next` once per night. Set it to 03:00 UTC
— after the 20:00 UTC junction tracker and its auto-merge window, and before US
daytime when `main` builds compete for the BST remote executor.

```yaml
on:
  schedule:
    - cron: '0 3 * * *'
jobs:
  dispatch:
    runs-on: ubuntu-latest
    permissions:
      actions: write
    steps:
      - run: gh workflow run build.yml --repo "${{ github.repository }}" --ref next
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

### `sync-main-to-testing` does not need a GitHub App token (2026-06-19)

`reusable-sync-branches.yml` declares `GH_TOKEN` as `required: false` and falls
back to `github.token`. The `promote` job in `publish.yml` already fast-forwards
the `testing` branch with `GITHUB_TOKEN` on every publish cycle — proof that no
App token is needed. Remove the `generate-token` job and both `BLUEFINBOT_*`
secret references entirely.

| "I'll just load the giant CI file." | That's how agents waste context. Route first, then go narrow. |
| "The workflow name tells me enough." | Wrong. Trigger type, branch filter, and reusable call semantics are usually the bug. |
| "Smoke failed, publish is broken." | Not necessarily. First check whether the failure is in the hard gate or in observational signal. |
| "I know GitHub Actions permissions from memory." | Good way to ship another `startup_failure`. Verify with Context7. |

## Red Flags

- Reading `ci-reference.md` before classifying the failure
- Editing reusable-workflow callers without checking top-level `permissions:`
- Treating AT-SPI smoke as the same class of signal as boot-check
- Changing publish/promotion behavior without mapping the branch and trigger path first
- Adding more prose to a router instead of splitting a focused skill

## Verification

After using this router, confirm:
- [ ] You identified the exact CI failure class before deep reading
- [ ] You loaded only the next relevant skill file
- [ ] You read the actual workflow being changed
- [ ] Any GitHub Actions or bootc syntax change was verified via Context7
- [ ] The lesson landed in a focused skill, not as more sprawl in the router
### Promotion PR stuck at UNKNOWN mergeability (2026-06-19)

**Symptom:** Promotion PR shows `mergeable: UNKNOWN` / `mergeStateStatus: UNKNOWN`
permanently. Web UI shows "Checking for the ability to merge automatically..." and
never resolves. `gh pr merge --squash` errors with "Head branch is out of date."

**Root cause:** `sync-main-to-testing.yml` fires on every push to `main` and its
`cleanup-squash-branch` job unconditionally deletes `auto/promote-testing-to-main`.
If any normal PR merges to `main` while a promotion PR is open, the squash branch
gets deleted. GitHub then permanently reports `UNKNOWN` mergeability for that PR.

**Recovery:**
```bash
gh pr close <promotion-pr> --repo projectbluefin/dakota \
  --comment "Closing — squash branch was deleted. Re-triggering."
gh workflow run promote-testing-to-main.yml --repo projectbluefin/dakota
```

**Systemic fix:** PR #931 guards the cleanup step — it skips deletion when an
open PR targets the squash branch. Also fixed in `projectbluefin/actions`:
`reusable-promote-squash.yml` now has `contents: write` and `pull-requests: write`
so `gh pr merge --auto` actually enables auto-merge on creation.

---

### `gh pr merge --auto` requires `contents: write` in reusable workflows (2026-06-19)

When a reusable workflow declares `permissions: contents: read`, GitHub restricts
it to read-only even if the caller grants `write`. `gh pr merge --auto` silently
fails — the PR gets no auto-merge flag and the maintainer sees "Enable automerge".

**Fix:** Add `contents: write` (and `pull-requests: write`) to the reusable
workflow's `permissions` block. Applied to:
- `projectbluefin/actions/reusable-promote-squash.yml` (promotion PRs)
- `projectbluefin/dakota/.github/workflows/pr-triage.yml` (regular PRs via #927)

**Diagnostic:** Check `autoMergeRequest` is non-null after the workflow runs:
```bash
gh pr view <n> --repo projectbluefin/dakota --json autoMergeRequest \
  --jq '.autoMergeRequest != null'
```
If `false`, the `gh pr merge --auto` call failed — check the workflow's declared
`permissions` first.

### testing branch is independent — no fast-forward from main (2026-06-21)

`testing` is an independent branch, identical to bluefin/bluefin-lts. It does NOT get
fast-forwarded from `main`. BST-changing merges to `testing` trigger their own build
and `:testing` publish. GHA-only merges (Renovate workflow pins) are filtered out.

**Push trigger paths-ignore** in `build.yml`:
```yaml
push:
  branches: [main, next, testing]
  paths-ignore:
    - '.github/workflows/**'   # workflows don't affect the image
    # .github/actions/** intentionally NOT ignored — local composite actions are used in build
    - 'docs/**'
    - '**.md'
    - 'AGENTS.md'
```

**Flow:**
```text
BST PR → testing → build → :testing published
GHA-only PR → testing → filtered, no build
promote PR: testing → main → build → stable
```

The previous `Fast-forward testing branch` step in `publish.yml` was disabled (`if: false`)
in PR 1004. It caused a redundant 5h rebuild: main build → fast-forward testing → push
to testing → second full rebuild of identical content. Fix: PR 997 removed testing from
push triggers entirely (broke :testing publishing); PR 1004 restored push trigger with
paths-ignore and removed the fast-forward instead.

### sync-main-to-testing.yml is required — do not remove it

After a `testing → main` promotion squash merge, the squash commit lands on `main`
but not in `testing`. `sync-main-to-testing.yml` merges main back into testing so
the next promotion PR is not blocked by a diverged history.

This is **not** the same as the removed publish.yml fast-forward step (which
caused double builds on every main push). The sync only fires on push to `main`
and handles a structural necessity of the squash-merge promotion model.

### Rapid-fire PR merges cancel pending builds

GitHub Actions concurrency with `cancel-in-progress: false` prevents in-progress
jobs from being cancelled, but **pending** (queued) jobs are replaced when a new
push arrives for the same concurrency group. Merging many PRs in quick succession
results in all but the last build being cancelled.

**Symptom:** All recent builds on a branch show `cancelled` status.

**Fix:** Trigger manually after the queue settles:
```bash
gh workflow run build.yml --ref main        # or --ref testing
```
Always check for cancelled builds after batch-merging PRs.

### PR triage gate — testing-first model

The `pr-triage.yml` gate enforces branch targets. In the testing-first model:
- PRs targeting `testing` → allowed (all content PRs)
- PRs targeting `next` → allowed (GNOME master stream)
- PRs targeting anything else (stable, latest) → blocked

If the gate is only allowing `renovate/*` branches to target testing (old state),
update it to allow all branches targeting testing. See PR 1009.

### Renovate must not manage projectbluefin/* — one exclusion rule covers all (2026-06-21)

All `projectbluefin/*` actions (`projectbluefin/actions`, `projectbluefin/testsuite`,
`projectbluefin/bonedigger`) use org-managed tags (`@v1`, `@main`). Renovate must
not generate SHA-bump or pin-digest PRs for any of them.

**Pattern that caused churn:** `pinDigests: true` applied globally, then a group rule
for `projectbluefin/actions` that didn't set `pinDigests: false`. Renovate generated
paired PRs every actions release:
- "update projectbluefin/actions" — SHA bump
- "pin dependencies" — re-pins things that got unpinned

**Correct renovate.json5:**
```json5
{
  "matchDepNames": ["/^projectbluefin\\//"],
  "enabled": false,
  "pinDigests": false
}
```
One rule. Replaces all per-package exemptions (`bonedigger`, `actions`, etc.).

### Renovate automerge label must be in the general rule (2026-06-21)

The `renovate-automerge.yml` workflow uses the `automerge` label as its signal.
The general automerge rule must include labels or Renovate digest/patch PRs stall
with no auto-merge trigger:

```json5
{
  "matchUpdateTypes": ["digest", "pin", "patch", "minor"],
  "automerge": true,
  "automergeType": "pr",
  "automergeStrategy": "squash",
  "labels": ["chore/deps", "automerge"]
}
```

Without this, only PRs created by per-package group rules (that explicitly set labels)
get the `automerge` label. Everything else opens with `pr/needs-review` only and stalls.

### update-iso-table.yml removed — [skip ci] churn (2026-06-21)

`update-iso-table.yml` ran every 6 hours and committed docs to `main` with `[skip ci]`.
Even with `[skip ci]`, the commits touched `main` and caused noise. Removed.

If ISO table needs updating in future, do it on demand via `workflow_dispatch` or
move it to the dakota-iso repo where it naturally belongs.

### testing branch must have required check for auto-merge to work (2026-06-21)

`gh pr merge --auto` requires the target branch to have at least one required
status check or required review. `testing` had no protection — `--auto` silently
failed with a warning, leaving approved PRs stuck indefinitely.

**Fix:** add `validate` as a required check on `testing` via the API:

```bash
gh api repos/projectbluefin/dakota/branches/testing/protection \
  -X PUT --input - << 'PROTECTION'
{
  "required_status_checks": {"strict": false, "contexts": ["validate"]},
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": true
}
PROTECTION
```

`allow_force_pushes: true` is required — the promote workflow force-pushes the squash branch.

### pr-triage auto-merge must fall back to direct merge (2026-06-21)

`--auto` can fail even on protected branches (race between approval and checks completing,
or protection not yet propagated). The correct pattern in `on-pr-review`:

```bash
if gh pr merge "$PR_URL" --auto --squash 2>/dev/null; then
  echo "auto-merge enabled"
else
  gh pr merge "$PR_URL" --squash 2>/dev/null \
    && echo "merged directly" \
    || echo "::warning::checks still running"
fi
```

Without the fallback, approved PRs with already-green CI sit permanently unmerged.

### OCI-native daily promotion model — pipeline timing and deleted workflows (2026-06-23)

Dakota migrated from a weekly squash-PR ceremony to a daily OCI-native promotion
flow (issue 1073). Key operational facts for CI debugging:

**Deleted workflows (do not recreate):** `promote-testing-to-main.yml`, `pr-release-gate.yml`, `sync-main-to-testing.yml`, `cache-warm.yml`.

**Daily BST build windows (workflow runs serialize; x86 variants do not):**
```
03:00 UTC  nightly-next-build → next branch
13:00 UTC  build.yml schedule → four x86 variants concurrently on four BuildBox slots
on success publish.yml → four stream images exported and published in parallel
on publish build-aarch64.yml → ARM default (decoupled)
on publish execute-release.yml → freshness check → promote
20:00 UTC  track-next-junctions → may trigger next junction build
```

**`cache-warm.yml` is deleted.** The daily 13:00 UTC `build.yml` schedule replaces it. CAS stays warm as long as the daily build runs. If the daily build is absent for >48 hours, expect cold-start non-determinism.

**ARM build trigger changed.** `build-aarch64.yml` now fires via `workflow_run` from `publish.yml` on `testing` — not a Tuesday cron. This ensures ARM starts only after x86 CAS writes complete, preventing write contention that was causing `Cached elements after warm: 0`.

**SHA-based freshness check.** `execute-release.yml` compares the `:testing` image digest to the current `:stable` digest. If they are equal, promotion is skipped (nothing new to ship). If different, the promote path runs: cosign verify → boot-check → skopeo copy → fast-forward main. The SHA used for cosign verify comes from `github.event.workflow_run.head_sha`, not a live `:testing` tag lookup.

**`testing` is now the default GitHub branch.** All PRs target `testing`. The old `main`-targeting PRs pattern is gone. `main` is a bookmark.

### Semi-cold RE builds overflow the runner disk — "Cache too full" cascade (2026-07-09)

Run 29037334809 died with 553 consecutive `FAILURE Cache too full` element failures
(~14s apart) starting ~38 min into the build phase. Underlying error from
buildbox-casd: `CaptureFiles ... RESOURCE_EXHAUSTED` /
`OutOfSpaceException: Insufficient storage quota` (`buildboxcommon_lrulocalcas.cpp`).

**Mechanism:** with remote execution enabled (nested `remote-execution.storage-service`,
no top-level `cache.storage-service`), BST mirrors every remotely-built element's output
files into the runner's local CAS at `~/.cache/buildstream`. On a warm run only the OCI
assembly deps are pulled and everything fits in the ~53 GB free on `/`. On a semi-cold
run (e.g. after a junction bump invalidates cache keys), every element in the ~9k graph
lands locally, including build-only toolchain artifacts — the disk fills, and BST cannot
prune mid-session because every pulled object is referenced by the current session's
targets. `retry-failed: True` then churns fast failures forever; the run never recovers.

**Detection:** `grep -c "Cache too full"` in the build log. One occurrence means the
local disk is exhausted — cancel the run; it will not recover.

**Fix (build.yml "Provision BST cache volume" step):** span the free space of `/`
(~40 GB) and `/mnt` (~55 GB) with two loopback files joined into a single btrfs
(`-d single -m single`) mounted at `~/.cache/buildstream` with
`compress-force=zstd:2,noatime`. CAS objects are mostly ELF binaries and debug info,
so zstd roughly doubles effective capacity (~95 GB raw -> ~150+ GB effective).

**Do not** reach for top-level `cache.storage-service` to keep content remote — that
reintroduces two documented failures: gRPC flooding after 3.5h (2026-06-24) and remote
per-client quota exhaustion (2026-06-09).

**Fallback if 150 GB is still not enough:** phase the build (`bst build` a subset,
`bst artifact push`, wipe local CAS, continue) — later phases re-pull only the runtime
deps of remaining elements.

### max-jobs: 1 in the RE config was the real 11-day build-time killer (2026-07-09)

The remote-execution BST config carried `build: max-jobs: 1`, added to prevent GCC
bootstrap OOM segfaults on gimple-match.cc. That meant EVERY remote build action ran
`make -j1` / `ninja -j1` — one core of the 16c/32t 7950X3D builder. Small elements
hide it; llvm and the two WebKit variants become 10-30h single-core compiles that
mathematically bust the 480m job budget. This, not CAS behavior, is why semi-cold
builds ran 6h+ and timed out repeatedly.

**Why raising it is safe:**
- max-jobs does not affect BST cache keys (`buildelement.py`: "normally automatically
  resolved and does not affect the cache key") — the warm CAS is fully preserved.
  Only `notparallel` elements pin to 1, and that IS keyed separately.
- The GCC bootstrap OOM is obsolete: the -O1 patch fixed the ICE, and gcc/bootstrap
  artifacts are already cached in the remote CAS.
- 128 GB RAM on the builder handles two concurrent -j16 actions.

**Setting:** `max-jobs: 16` with `builders: 2` — two concurrent actions saturate
all 32 threads. If a genuinely memory-hungry element OOMs at -j16, use an
element-scoped fix (variables in a repo patch), never a global -j1.

**Changing max-jobs mid-outage costs nothing:** already-built elements pull from the
artifact cache by BST cache key; only not-yet-built elements get new RE action digests.

### max-jobs: 16 crashed the RE server — 8 is the ceiling (2026-07-09)

The first run at `max-jobs: 16` died at ~23:20 UTC: gcc-stage1.bst, 28 minutes into
its remote action, got `INTERNAL: Stream removed (Received RST_STREAM with error
code 2)`, and simultaneously every artifact pull started failing with `FetchBlob
failed with status DEADLINE_EXCEEDED`. The whole CAS/RE endpoint at
cache.projectbluefin.io:11002 stopped serving mid-run, then recovered on its own
(TLS handshake succeeded again minutes after the run failed).

**Diagnosis:** likely server-side OOM. gimple-match.cc and friends eat 4-6 GB per
compiler process; 16 parallel jobs plus buildbox-casd's own cache pressure exceeds
the 128 GB builder, the worker (or the whole host) OOMs, and every open gRPC stream
gets RST_STREAM'd. From the client all you see is one build failure plus mass
DEADLINE_EXCEEDED on unrelated pulls — the correlated timing is the tell.

**Signature to recognize:** one RE action fails with `Stream removed / RST_STREAM
error code 2` AND pulls fail en masse with `FetchBlob ... DEADLINE_EXCEEDED` at the
same timestamp = server-side crash/restart, not a client or network problem. Probe
recovery with `echo | openssl s_client -connect cache.projectbluefin.io:11002`
(no SSH access to the server exists from CI or dev machines).

**Setting:** `max-jobs: 8` with `builders: 2`. Still 8x the old -j1 throughput,
peak compile RAM ~2x8x6 GB = ~96 GB worst case, under the ceiling. Do not raise
back to 16 without server-side memory monitoring in place.

### RE backend is buildbarn on the ghost cluster — 30m default action timeout was the real killer (2026-07-10)

cache.projectbluefin.io:11002 is NOT an opaque external service: it is the buildbarn
grid on the ghost k3s cluster (namespace buildbarn: frontend x2, scheduler, storage x2,
worker on ghost + exo-0), managed by GitOps from projectbluefin/lab manifests/
(ArgoCD app testing-lab-infra). kubectl access from the dev machine works. When "the
server" misbehaves, debug it directly:

- `kubectl get pods -n buildbarn` — look for restarts; exo-0 node crashes take out
  scheduler + storage-0 + one worker simultaneously.
- Scheduler queue is in-memory: a scheduler restart LOSES all queued actions, and the
  BST client's "Waiting for the remote build to complete" then hangs forever (no
  requeue, no error). A run frozen on one action after a scheduler restart is dead —
  cancel it.
- Worker log line `Action: ... with timeout 30m0s` reveals the effective action
  timeout. BST sends no explicit timeout, so buildbarn's defaultExecutionTimeout in
  the initialSizeClassAnalyzer block is the cap on EVERY remote compile. It was
  1800s — gcc-stage1/llvm/webkit (1-4h actions) were killed at 30m every time, which
  produced the recurring "big element dies ~30min in" outage pattern. Fixed in
  projectbluefin/lab manifests/buildbarn-config.yaml: default 21600s, max 28800s.
  Config change requires `kubectl rollout restart deploy/scheduler -n buildbarn`
  (config loads at start) — restart only when no build is running.
- The 2026-07-09 "-j16 crashed the server" hypothesis was wrong: the RST_STREAM +
  DEADLINE_EXCEEDED outage was the exo-0 node crashing (all its pods exited 255 at
  once), unrelated to compile parallelism.

Also observed: a healthy warm run reaches ~91% of elements (pull+fetch) in ~25 min;
the remaining ~95 elements are the real rebuild tail. GH job log API flushes in ~5k
line chunks and build-phase output is sparse — hours of flat line-count is normal.

   ### Current build workflow path (2026-07-11)

   The workflow no longer uses the RE NOT_FOUND hotfix, the retry loop, or the
   output-stall watchdog added during the 2026-07-10 outage. The supported Dakota
   path is a single direct `just bst build ...` invocation with the generated CI
   config that contains a `remote-execution:` block, using the regular BuildStream
   container.

   If a run appears stuck, verify RE first with the fail-fast evidence checks above
   before layering on ad hoc workflow retries or podman hooks. Capture the run ID
   and monitor the build/publish pair from the CLI:

   ```bash
   just monitor-pipeline BUILD_RUN_ID=29125255417
   ```

   The helper polls `gh run view` for the build run, waits for it to finish
   successfully, and then resolves the follow-on `publish.yml` run by matching the
   build run's `headSha`. If the build or publish run fails, it exits non-zero so
   the terminal can be used in automation or local triage.

### Overriding cache servers in buildstream-ci.conf wipes upstream caches (2026-07-11)

When generating a custom `buildstream-ci.conf` in CI and specifying custom `artifacts` or `source-caches` blocks, BuildStream completely overrides the project-level cache servers defined in `project.conf` rather than appending to them.

**The Failure Pattern:** On core junction bumps (e.g. freedesktop-sdk or gnome-build-meta updates), if the generated config overrides the server list to contain only the projectbluefin CAS, there is a cache miss on almost the entire universe. Because the upstream read-only caches (`gbm.gnome.org:11003` and `cache.freedesktop-sdk.io:11001`) are absent from the overridden configuration, BuildBarn (or the runner, if RE is also broken) is forced to download sources and compile the entire SDK/GNOME desktop. This causes multi-hour compiles that trigger OOM, worker timeouts, or runner timeouts.

**The Fix:** Always include a `remote-execution:` block routed through `cache.projectbluefin.io:11002` and include the upstream read-only caches as fallback servers in any overridden `artifacts` and `source-caches` blocks within the generated `buildstream-ci.conf`. This preserves 100% cache alignment with upstream SDK/GNOME builds and allows BuildBarn to pull pre-built SDK/GNOME artifacts instantly. With RE enabled, project-specific elements are built remotely, not assembled locally on the runner.

### GHCR tag visibility needs an explicit verification barrier

A successful `podman push` is not sufficient evidence that a newly pushed immutable
SHA tag is immediately readable by other GitHub-hosted runners. The 2026-07-20
publish completed its default push, but the follow-on smoke and release jobs saw
`manifest unknown` for the same SHA. Treat GHCR visibility as a separate readiness
condition: retry `skopeo inspect` after the push, before moving `:testing`, and again
in any `workflow_run` consumer before pulling the image. This keeps eventual
registry consistency from producing false smoke failures or a release job that
races a tag that is not yet readable.

### `skopeo inspect --creds` fails for public GHCR in workflow_run jobs (2026-07-28)

Using `skopeo inspect --creds "$GH_ACTOR:$GH_TOKEN"` to verify a public GHCR tag
after push fails silently in `workflow_run`-triggered jobs. The credentials are
valid (the push succeeds using `podman login`), but `skopeo inspect` with those
credentials returns an error for public packages in this trigger context.

**Root cause:** The `GITHUB_TOKEN` scoped to a `workflow_run` event does not have
permission to read packages via the skopeo credential path for public registries.
The push (via `podman`, which uses the stored login) succeeds; only the post-push
verification via `skopeo inspect --creds` fails.

**Fix:** Remove `--creds` from all `skopeo inspect` calls that verify public GHCR
visibility. Unauthenticated access works for public packages:
```bash
# ❌ fails in workflow_run context
skopeo inspect --creds "$GH_ACTOR:$GH_TOKEN" "docker://${IMAGE}:${SHA}"

# ✅ correct — public packages need no credentials
skopeo inspect --no-tags "docker://${IMAGE}:${SHA}"
```
Authenticated `skopeo copy` (for actual tag promotion) still needs `--src-creds`/`--dest-creds`.

### workflow_run uses the DEFAULT BRANCH version of the workflow file (2026-07-28)

When a `workflow_run`-triggered workflow fires (e.g. publish.yml triggered by
Build Bluefin dakota completing), GitHub uses the workflow file from the **default
branch** of the repository, NOT from the `head_sha` of the triggering run.

**Implication for Dakota:** Dakota's default branch is `testing`. So publish.yml
always runs the version at the current `testing` HEAD — even when the build SHA
(`github.event.workflow_run.head_sha`) points to an older commit. The repo checkout
inside the job uses `ref: ${{ needs.setup.outputs.sha }}` (the build SHA), but the
*workflow logic itself* is from the default branch.

**Why this matters:** Fixes to publish.yml pushed to `testing` take effect on the
NEXT publish run, even if the next publish is for an older build SHA. You do NOT
need to cherry-pick workflow fixes back to the build SHA — pushing to `testing` is
sufficient.

### main/testing divergence causes force=false fast-forward failure (2026-07-28)

If commits land directly on `main` (bypassing the testing→promotion flow), `main`
diverges from `testing`. The reusable `execute-release.yml` action does a
`force=false` fast-forward of `main` to the promoted SHA, which fails if `main`
has commits that aren't in the promoted SHA's ancestry.

**Pattern:** `main` shows as "diverged" vs the build SHA. The reusable action's
`gh api ... --method PATCH --field force=false` returns HTTP 422.

**Fix:** Remove `fast_forward_branch` from the reusable action call. Add a separate
`update-main-bookmark` job that uses `force=true`:
```yaml
update-main-bookmark:
  needs: [freshness-check, execute]
  if: always() && needs.execute.result == 'success'
  runs-on: ubuntu-latest
  permissions:
    contents: write
  steps:
    - name: Force-update main to promoted SHA
      env:
        GH_TOKEN: ${{ github.token }}
        TARGET_SHA: ${{ needs.freshness-check.outputs.build_sha }}
      run: |
        compare=$(gh api "repos/${{ github.repository }}/compare/${TARGET_SHA}...main" \
          --jq '.status' 2>/dev/null || echo "unknown")
        [ "$compare" = 'identical' ] && exit 0
        gh api "repos/${{ github.repository }}/git/refs/heads/main" \
          --method PATCH --field sha="$TARGET_SHA" --field force=true
```

**Prevention:** Never commit directly to `main`. All changes must go through PRs
against `testing`. The stable bookmark (`main`) is only written by the
execute-release.yml promotion flow.

### promote_sha input for SHA-mismatch recovery (2026-07-28)

After pushing workflow-only fixes to `testing`, the testing HEAD advances past the
build SHA. The execute-release auto-trigger then sees `CURRENT_SHA != BUILD_SHA`
(build: `a1a76d1`, testing HEAD: `736ba44`) and skips promotion with "testing has
advanced — will promote next build."

**Fix:** Add a `promote_sha` workflow_dispatch input that bypasses the SHA mismatch
guard. When set, the workflow uses the specified SHA instead of the live testing HEAD,
and skips the mismatch check. Use this for recovery after workflow-only commits to
testing:
```bash
gh workflow run execute-release.yml \
  --repo projectbluefin/dakota \
  --ref testing \
  -f promote_sha=<the-build-sha>
```

### Publishing is the deliverable — do not over-verify (2026-07-09)

When `:testing` is stale or CI is broken, pushing the validated fix is the primary
task. Targeted validation (the failing element builds past its failure point,
`just validate`, `just patch-drift-check`) is sufficient push evidence; a full local
image build is never a push prerequisite — CI performs that verification itself.
A stale `:testing` outage was extended a full day by an unnecessary 8-hour local
verification build.
