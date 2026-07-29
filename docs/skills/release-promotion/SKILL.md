---
name: release-promotion
description: Dakota's automated promotion to :stable — freshness comparison against the built SHA, identity-anchored cosign verification, bookmark fast-forward, post-release checks, and rollback. Load when a promotion did not happen or must be undone.
---

# Release Promotion

## Overview

Promotion is a verified tag copy, not a build. The release workflow decides
whether the published SHA differs from `:stable`, verifies the signature,
copies the tag, fast-forwards the release bookmark, publishes notes, and then
re-verifies what it just did. There is no promotion PR and no human approval
in the path. `docs/release.md` states the trust contract this implements.

## When to use

- `:stable` did not move after a successful publish
- A promotion step failed, or the release notes are missing
- A bad image reached `:stable` and must be rolled back
- Changing anything in the promotion or rollback path

## When not to use

- The publish itself failed → [ci-triage](../ci-triage/SKILL.md)
- The boot gate failed → [e2e-ci](../e2e-ci/SKILL.md)
- ARM tags or the multi-arch manifest → [aarch64](../aarch64/SKILL.md)

## Authoritative sources

- `.github/workflows/execute-release.yml` — freshness, promotion, notes, verify
- `.github/workflows/rollback-stable.yml` — the reverse path, dry-run by default
- `docs/release.md` — what `:stable` guarantees and why
- `Justfile` — the `verify` recipe for checking a published image locally

## Workflow

1. **Check whether promotion was skipped rather than failed.** The freshness
   job exits cleanly when the published SHA already matches `:stable`, when
   the upstream publish did not succeed, or when the trunk branch advanced
   past the SHA that was built. All three are correct outcomes.
2. **Read the actual `needs:` topology, not a linear story.**
   `freshness-check` gates `execute`. After `execute`, `release-notes` and
   `create-multiarch-stable` can run in parallel. `post-release-variants`
   needs `execute` + `release-notes`. `post-release-verify` needs
   `freshness-check` + `execute` + `create-multiarch-stable`, and does **not**
   depend on `release-notes` or `post-release-variants`.

   ```text
   freshness-check → execute
   freshness-check + execute → release-notes
   execute + release-notes → post-release-variants
   freshness-check + execute → create-multiarch-stable
   freshness-check + execute + create-multiarch-stable → post-release-verify
   ```

   Each job in `.github/workflows/execute-release.yml` fails independently.
3. **Treat the SHA as the decision input.** Every comparison, verification,
   and copy is anchored to the specific built SHA rather than to the floating
   stream tag, so the image that was evaluated is the image that is promoted.
   Do not reintroduce a floating-tag lookup anywhere in this path.
4. **Keep the certificate identity anchored.** Verification restricts the
   signing identity to the publishing workflow file on allowed refs, anchored
   at both ends. An unanchored pattern would accept a signature produced by
   any workflow in the repository.
5. **To roll back, dispatch the rollback workflow with the previously
   promoted SHA.** It defaults to a dry run: it inspects and verifies
   signatures without moving anything, so run it once to confirm the target
   before opting into the live move.
6. **Do not add a PR, queue step, or additional gate here.** Promotion is
   intentionally a direct verified copy plus a bookmark fast-forward.

## Failure modes

### The bookmark cannot fast-forward

The release bookmark only ever advances to a promoted SHA. If it holds
commits that are not on the trunk branch it will not fast-forward, and the
post-release check that compares the bookmark against the promoted SHA fails.
Never open pull requests against the bookmark branch.

### The signing identity is duplicated across files

The anchored identity pattern appears in the promotion workflow, the rollback
workflow, and the local verification recipe. They must describe the same
publishing workflow and the same allowed refs; when the publishing branch
changes, all copies change together or verification fails somewhere that is
not exercised daily.

### Release notes depend on a published artifact

Notes are generated from the SBOM artifact produced by the publish workflow
rather than re-scanned at release time, because a post-build scan of a
BuildStream image under-reports packages. If the artifact is missing or
expired, fix the publish side; do not swap in an inline scanner.

## Verification

```bash
# Recent promotion runs
gh run list --repo projectbluefin/dakota --workflow execute-release.yml --limit 5

# Does :stable point at the digest of the promoted SHA?
skopeo inspect --no-tags docker://ghcr.io/projectbluefin/dakota:stable | jq -r .Digest
skopeo inspect --no-tags docker://ghcr.io/projectbluefin/dakota:<sha> | jq -r .Digest

# Does the bookmark match the promoted SHA?
gh api repos/projectbluefin/dakota/branches/main --jq '.commit.sha'

# Signature, SBOM referrer, and attestation for a published image
just verify ghcr.io/projectbluefin/dakota:stable

# Every place the anchored signing identity is declared
rg -n -A2 'certificate-identity-regexp|cosign_identity_regexp|cert_identity_regexp' \
  .github/workflows Justfile
```

## Related skills

- [e2e-ci](../e2e-ci/SKILL.md) — the boot gate that qualifies an image
- [aarch64](../aarch64/SKILL.md) — the best-effort multi-arch manifest
- [ci-triage](../ci-triage/SKILL.md) — routing when the failure is upstream
- [ci-tooling](../ci-tooling/SKILL.md) — permissions for reusable release calls
