---
name: dakota-ci
description: Diagnose or change Dakota validation, build, publish, e2e, cache, remote-execution, and architecture workflows.
---

# Dakota CI

Workflow YAML is the current source of truth. Do not rely on historical runbooks
when the workflow says something different.

## Route the problem

| Area | Source |
|---|---|
| Graph and patch validation | `.github/workflows/validate.yml` |
| x86 variant builds | `.github/workflows/build.yml` |
| aarch64 build and boot | `build-aarch64.yml`, `boot-test-aarch64.yml` |
| Image export and publication | `publish.yml` |
| Manual image e2e and testsuite | `e2e.yml`, `run-testsuite.yml` |
| Next stream scheduling | `nightly-next-build.yml`, `sync-next.yml` |
| Stable promotion | Load `dakota-release` |

## Diagnose before editing

1. Identify whether the failure happened before jobs started, during source
   fetch, BuildStream execution, artifact transfer, image publication, or test.
2. Read the failing workflow at the commit that ran—not only the current branch.
3. Inspect the first failing job and preserve its exact error.
4. Compare other runs only to distinguish infrastructure-wide failures from a
   branch regression.
5. Verify GitHub Actions behavior in current official documentation before
   changing triggers, permissions, expressions, reusable calls, or concurrency.
6. Apply the narrowest fix and run `just validate` plus any workflow-specific
   local check exposed by the Justfile.

## Rules

- Third-party actions use full commit SHAs with version comments.
  `projectbluefin/actions@v1` is an intentional managed-tag exception.
- Caller permissions must cover every permission requested by a reusable
  workflow; invalid permission names cause startup failure without job logs.
- Build and publish are separate: publish can only materialize an OCI artifact
  that the build placed in the CAS.
- Remote cache access and remote execution are separate capabilities. Diagnose
  them separately.
- Do not serialize intentional matrix siblings or cancel unrelated active runs
  without explicit operator direction.
- Do not require a full local image build before publishing a targeted,
  validated fix; CI owns full-image verification.
- Keep observational jobs off the release-critical dependency path unless they
  are deliberately promoted to hard gates.

## Validation

- YAML parses and expressions are supported in their event context.
- `just validate` passes when BST-affecting files changed.
- Required checks still start for every protected-branch event they gate.
- The reported result distinguishes local validation, pending CI, and green CI.

## Reference

- [`docs/ci.md`](../../../docs/ci.md)
- [`.github/workflows/`](../../../.github/workflows/)
