---
name: aarch64
description: Dakota's aarch64 build path — a standalone workflow that never gates x86_64, its own cache and concurrency settings, SHA-pinned tag and signature ordering, and the best-effort multi-arch stable manifest. Load when working on ARM builds or stale ARM tags.
---

# aarch64

## Overview

Dakota builds an aarch64 image alongside x86_64. The invariant is that ARM
can never block, gate, or delay an x86_64 build, publish, promotion, or
release. That is enforced structurally: a standalone workflow, its own
concurrency group, no job dependency in either direction, and a multi-arch
manifest step that skips silently when no ARM image exists.

## When to use

- Changing the aarch64 build workflow or its BuildStream options
- The `:aarch64` tag or the multi-arch manifest is stale or missing
- Adding aarch64 to another artifact or verification step

## When not to use

- x86_64 publish or promotion → [release-promotion](../release-promotion/SKILL.md)
- Element build failures shared with x86_64 → [debugging](../debugging/SKILL.md)
- Workflow permissions or cache config → [ci-tooling](../ci-tooling/SKILL.md)

## Authoritative sources

- `.github/workflows/build-aarch64.yml` — the standalone ARM build
- `.github/workflows/execute-release.yml` — the multi-arch manifest job
- `Justfile` — `just bst ... --option arch aarch64`, `just export`, `just lint`

## Workflow

1. **Keep the workflow standalone.** It runs on ARM runners, marks itself
   non-blocking, and uses a per-ref concurrency group of its own. Do not add a
   dependency from any x86_64 job to it, and do not merge its concurrency
   group into the shared build lock — concurrent writers to the remote cache
   destroy the hit rate for both.
2. **Build ARM with pushing to the cache enabled.** There is no remote
   execution service for ARM, so the build runs locally on the runner and
   pushes artifacts so later runs start warm. This is the opposite of the
   x86_64 build, which pushes in a dedicated step after the build succeeds.
3. **Preserve the tag ordering.** The immutable SHA-pinned tag is pushed
   first with its digest captured, then the floating tag is pushed to the same
   manifest, and signing uses the captured digest. Signing the floating tag
   would sign whatever it happens to point at.
4. **Reference ARM by SHA-pinned tag downstream.** The multi-arch manifest job
   looks for the SHA-pinned ARM image for the promoted commit, verifies it by
   digest, and composes the manifest from digests — not from floating tags.
5. **Recover a stale tag by dispatching the workflow.** A failed ARM build
   leaves the previous tag in place; x86_64 is unaffected and needs no action.

## Failure modes

### A missing ARM image is a skip, not a failure

The manifest job checks for the SHA-pinned ARM image and exits cleanly when
it is absent, because x86_64 `:stable` is already live at that point. Making
that step required would let an ARM runner outage block stable releases.

### Signing the floating tag instead of the pushed digest

Verification downstream resolves the ARM component by digest. If signing is
moved to the floating tag, the manifest can publish a component whose digest
was never verified — the exact gap the digest-pinned flow closes.

### ARM builds are long and share the cache

The ARM build runs after the x86_64 publish so the two are not writing to the
remote cache at once, and its timeout is sized for a slower runner. Moving it
earlier reintroduces write contention on the shared cache.

## Verification

```bash
# Recent ARM builds
gh run list --repo projectbluefin/dakota --workflow build-aarch64.yml --limit 5

# Is the ARM tag fresh, and does a SHA-pinned tag exist for a given commit?
skopeo inspect --no-tags docker://ghcr.io/projectbluefin/dakota:aarch64 | jq -r .Created
skopeo inspect --no-tags docker://ghcr.io/projectbluefin/dakota:aarch64-<sha> | jq -r .Digest

# Is the multi-arch manifest present?
skopeo inspect --raw --no-tags docker://ghcr.io/projectbluefin/dakota:stable-multiarch

# Confirm ARM keeps its own concurrency group
rg -n -A3 '^concurrency:' .github/workflows/build-aarch64.yml
```

## Related skills

- [release-promotion](../release-promotion/SKILL.md) — where the manifest is built
- [ci-triage](../ci-triage/SKILL.md) — routing an ARM failure correctly
- [debugging](../debugging/SKILL.md) — element failures that are not ARM-specific
