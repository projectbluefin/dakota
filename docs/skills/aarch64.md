---
name: aarch64
description: Design and operational guidance for Dakota's aarch64 build pipeline. Covers the decoupling model, build-aarch64.yml workflow, and why ARM must never block x86_64. Load when working on aarch64 builds, the build-aarch64.yml workflow, or investigating stale aarch64 tags.
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
- Debugging why `:aarch64` tag is stale
- Adding aarch64 to a new release artifact (e.g. multi-arch manifest)

## When NOT to Use

- x86_64 publish or promotion problems → `workflow-map.md` + `release-promotion.md`
- Historical CI deep cuts → `ci-reference.md`

## Decoupling Model

aarch64 is a **separate workflow** (`build-aarch64.yml`), triggered after x86_64 publishes:

```
publish.yml (testing) → [workflow_run] → build-aarch64.yml
  └─ build-aarch64 job (ubuntu-24.04-arm, continue-on-error: true)
       ├─ BST build (no RE, enable-push: true)
       ├─ export + bootc lint
       └─ push :aarch64 and :aarch64-<sha> to GHCR

execute-release.yml (after :stable is live)
  └─ create-multiarch-stable (continue-on-error: true)
       └─ checks if :aarch64 exists → creates :stable-multiarch if present
          (skips silently if absent — x86_64 stable already live)
```

**No job in `publish.yml` or `execute-release.yml` has `needs:` on `build-aarch64.yml`.** The coupling is zero.

## Hard Rules

- `build-aarch64.yml` must have `continue-on-error: true` at the job level
- `build-aarch64.yml` must use a separate concurrency group (`build-aarch64-${{ github.ref }}`)
- Do not add aarch64 to `needs:` in `publish.yml` or `execute-release.yml`
- The `create-multiarch-stable` job in `execute-release.yml` must be `continue-on-error: true` and must never be in the critical path for `:stable`
- No Remote Execution for ARM yet (`enable-remote-execution: false`). Use `enable-push: true` to populate CAS for subsequent builds.

## Triggers

`build-aarch64.yml` has three triggers:
- `push: testing/main` (BST-affecting paths only, same paths-ignore as `build.yml`)
- `workflow_run` from `publish.yml` on `testing` — serializes ARM start after x86_64 CAS writes complete
- `workflow_dispatch` — manual recovery / on-demand

The `workflow_run` trigger is the primary production path. `push` provides direct ARM builds on BST-affecting commits to `testing` or `main`.

## Published Tags

| Tag | When | Source |
|---|---|---|
| `:aarch64` | workflow_run from publish, dispatch | Latest successful aarch64 build from testing |
| `:aarch64-<sha>` | workflow_run from publish, dispatch | Immutable per-commit aarch64 tag |
| `:stable-multiarch` | execute-release, if :aarch64 present | Multi-arch index combining :stable + :aarch64 |

## Recovery

```bash
# Re-trigger full aarch64 build
gh workflow run build-aarch64.yml --repo projectbluefin/dakota --ref testing
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Let me just add aarch64 to the publish.yml needs: so the manifest is created there." | No. Structural decoupling is the whole point. A failed ARM job must never stall x86_64 publication. |
| "ARM is ready, let's remove continue-on-error." | Only when aarch64 has the same reliability story as x86_64, and with explicit maintainer decision. |

## Lessons Learned

### aarch64 decoupling via separate workflow (2026-06-23)

The `build-aarch64` job was originally in `build.yml` with `if: false` (disabled). Moving it to a standalone `build-aarch64.yml` gives structural decoupling — no shared `needs:` graph, separate concurrency, and independent failure domain. The old inline job was removed entirely along with the defunct `create-manifest` job that depended on it.

**Key design decision:** The multi-arch manifest (`create-multiarch-stable`) lives in `execute-release.yml` rather than `build-aarch64.yml` because the `:stable` tag only exists after the x86_64 release completes. A post-release manifest step is safer than a racing parallel manifest job.

### ARM trigger updated to include workflow_run from publish (2026-06-23)

`build-aarch64.yml` previously used only a Tuesday cron + `push: testing/main` trigger. Added `workflow_run` from `publish.yml` on `testing` to also serialize ARM after x86_64 CAS writes complete. This eliminated the `Cached elements after warm: 0` failures caused by concurrent x86_64 and ARM CAS writes.

### Publish skips after docs-only commits (2026-06-22)

When all recent commits on `testing` are paths-ignored (docs/AGENTS.md only), no automatic build fires and `:testing` goes stale. Recovery: manual `workflow_dispatch` on `build.yml` targeting `testing`. After the build, `publish.yml` fires automatically, which then triggers `build-aarch64.yml`.

