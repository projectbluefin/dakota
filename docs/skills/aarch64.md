---
name: aarch64
description: Design and operational guidance for Dakota's aarch64 build pipeline. Covers the decoupling model, build-aarch64.yml workflow, cache-warm patterns, and why ARM must never block x86_64. Load when working on aarch64 builds, the build-aarch64.yml workflow, or investigating aarch64 cache-warm failures.
metadata:
  context7-sources:
    - /websites/github_en_actions
---

# aarch64 Build Pipeline

## Overview

Dakota ships an aarch64 OCI image alongside x86_64. The **hard invariant** is that ARM can never block, gate, or delay an x86_64 build, publish, promote, or release. This is enforced structurally — not just via `continue-on-error`.

## When to Use

Load this skill when:
- Working on `.github/workflows/build-aarch64.yml`
- Investigating aarch64 warm-cache failures in `cache-warm.yml`
- Debugging why `:aarch64` tag is stale
- Adding aarch64 to a new release artifact (e.g. multi-arch manifest)

## When NOT to Use

- x86_64 publish or promotion problems → `workflow-map.md` + `release-promotion.md`
- cache-warm for x86_64 → `ci-reference.md`

## Decoupling Model

aarch64 is a **separate workflow** (`build-aarch64.yml`), not a job in `build.yml`:

```
build-aarch64.yml (push: testing/main, Tue schedule, dispatch)
  └─ build-aarch64 job (ubuntu-24.04-arm, continue-on-error: true)
       ├─ BST build (no RE, enable-push: true)
       ├─ export + bootc lint
       └─ push :aarch64 and :aarch64-<sha> to GHCR

execute-release.yml (after :stable is live)
  └─ create-multiarch-stable (continue-on-error: true)
       └─ checks if :aarch64 exists → creates :stable-multiarch if present
          (skips silently if absent — x86_64 stable already live)
```

**No job in `publish.yml`, `promote-testing-to-main.yml`, or `execute-release.yml` has `needs:` on `build-aarch64.yml`.** The coupling is zero.

## Hard Rules

- `build-aarch64.yml` must have `continue-on-error: true` at the job level
- `build-aarch64.yml` must use a separate concurrency group (`build-aarch64-${{ github.ref }}`)
- Do not add aarch64 to `needs:` in `publish.yml`, `promote-testing-to-main.yml`, or `execute-release.yml`
- The `create-multiarch-stable` job in `execute-release.yml` must be `continue-on-error: true` and must never be in the critical path for `:stable`
- No Remote Execution for ARM yet (`enable-remote-execution: false`). Use `enable-push: true` to populate CAS for subsequent builds.

## Triggers

```yaml
on:
  push:
    branches: [main, testing]
    paths-ignore:
      - '.github/workflows/**'
      - 'docs/**'
      - '**.md'
      - 'AGENTS.md'
  schedule:
    - cron: '0 4 * * 2'   # Tuesday 04:00 UTC — same window as promote schedule
  workflow_dispatch:
```

The Tuesday schedule means aarch64 may be current when `execute-release.yml` fires its `create-multiarch-stable` step.

## Published Tags

| Tag | When | Source |
|---|---|---|
| `:aarch64` | push, schedule, dispatch | Latest successful aarch64 build from testing/main |
| `:aarch64-<sha>` | push, schedule, dispatch | Immutable per-commit aarch64 tag |
| `:stable-multiarch` | execute-release, if :aarch64 present | Multi-arch index combining :stable + :aarch64 |

## Warm Cache (cache-warm.yml)

The `warm-cache-aarch64` job in `cache-warm.yml` runs weekdays at 06:00 UTC alongside the x86_64 warm job. It is:
- `continue-on-error: true`
- Separate concurrency group: `dakota-cache-warm-aarch64`
- Uses `enable-remote-execution: false`, `enable-push: true`

**Common failure patterns:**

| Pattern | Symptom | Root cause |
|---|---|---|
| Cancelled warm-cache runs | `warm-cache-aarch64` cancelled repeatedly | Operator intervention (pre-flight cancels all active runs including warm jobs) |
| Failed warm-cache | `Cached aarch64 elements after warm: 0` | ARM runner not available, or gnome-build-meta upstream rebuilding for aarch64 |
| Long stale period | `:aarch64` not updated for days | All recent testing pushes are paths-ignored (docs/workflow-only) |

**Recovery:**
```bash
# Re-trigger warm cache manually
gh workflow run cache-warm.yml --repo projectbluefin/dakota

# Re-trigger full aarch64 build
gh workflow run build-aarch64.yml --repo projectbluefin/dakota --ref testing
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Let me just add aarch64 to the publish.yml needs: so the manifest is created there." | No. Structural decoupling is the whole point. A failed ARM job must never stall x86_64 publication. |
| "The cache-warm failed but it's non-blocking so ignore it." | Non-blocking today, but a cold CAS means the first real aarch64 build will be very slow or time out. Fix the root cause. |
| "ARM is ready, let's remove continue-on-error." | Only when aarch64 has the same reliability story as x86_64, and with explicit maintainer decision. |

## Lessons Learned

### aarch64 decoupling via separate workflow (2026-06-23)

The `build-aarch64` job was originally in `build.yml` with `if: false` (disabled). Moving it to a standalone `build-aarch64.yml` gives structural decoupling — no shared `needs:` graph, separate concurrency, and independent failure domain. The old inline job was removed entirely along with the defunct `create-manifest` job that depended on it.

**Key design decision:** The multi-arch manifest (`create-multiarch-stable`) lives in `execute-release.yml` rather than `build-aarch64.yml` because the `:stable` tag only exists after the x86_64 release completes. A post-release manifest step is safer than a racing parallel manifest job.

### Publish skips after docs-only commits (2026-06-22)

When all recent commits on `testing` are paths-ignored (docs/AGENTS.md only), no automatic build fires and `:testing` goes stale. The correct recovery is a manual `workflow_dispatch` on `build.yml` targeting the `testing` branch. After the build, `publish.yml` fires automatically (the `workflow_dispatch` event passes the `event != 'pull_request'` gate in the setup job).

The `promote-testing-to-main.yml` does NOT fire from `publish.yml` completing — it only fires on `push: testing` (git push). The Tuesday 04:00 UTC schedule is what drives the gate + auto-merge.
