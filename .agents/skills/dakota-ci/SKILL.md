---
name: dakota-ci
description: Diagnose or change Dakota validation, build, publish, e2e, cache, remote-execution, and architecture workflows.
metadata:
  context7-sources:
    - /apache/buildstream
---

# Dakota CI

Workflow YAML in `.github/workflows/` is the current source of truth. Do not rely on historical runbooks when the workflow says something different.

## When to Use

- Modifying or debugging GitHub Actions workflows in `.github/workflows/`
- Diagnosing runner startup, syntax, matrix, or permission failures
- Changing build, publish, or validation triggers and artifact flows
- Investigating remote CAS caching or remote execution integration

## When NOT to Use

- Stable promotion, image signing, cosign attestation, or rollback → load `dakota-release`
- BST element syntax or internal build errors → load `dakota-buildstream`
- Reviewing PRs and issue management → load `dakota-review`

## Core Process

1. **Route the Workflow**: Identify the failing workflow:
   - `validate.yml`: PR graph checks and patch drift
   - `build.yml` / `build-aarch64.yml`: Remote execution x86/ARM builds into CAS
   - `publish.yml`: CAS artifact checkout, squashing, tagging, signing
   - `e2e.yml`: Manual testsuite dispatch against published images
2. **Inspect at Run SHA**: Read the workflow YAML at the exact commit that executed.
3. **Isolate Root Cause**: Distinguish syntax/permission failure (zero jobs run), source fetch failure, remote CAS cache failure, or BST compilation error.
4. **Enforce Least Privilege**: Ensure workflow caller permissions strictly match what reusable workflows demand.
5. **Validate Locally**: Run `just check-publish-workflow` and `just validate` before submitting.

## Invariants

- **Third-Party Actions**: Pin all third-party actions to full 40-character commit SHAs with an inline version comment. `projectbluefin/actions@v1` is an intentional managed-tag exception.
- **Build vs Publish Separation**: `build.yml` writes artifacts to the remote CAS; `publish.yml` only exports artifacts already present in the CAS for that exact resolved SHA.
- **e2e Workflow Gate**: `e2e.yml` runs only via `workflow_dispatch` against an already-published tag. It does **not** gate PRs.
- **Atomic Matrices**: Do not cancel or serialize matrix siblings (`default`, `nvidia`, `gaming`, `nvidia-gaming`) without explicit human approval.
- **Truth in Reporting**: Never report CI as green while workflows are pending, queued, or skipped.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I will add `e2e.yml` to PR checks so we catch regressions earlier." | PRs do not push images to GHCR. Running e2e on a PR tests a stale public tag, not the PR. |
| "A commit SHA is overkill; a version tag like `@v2` is fine." | Tags are mutable. Security policy requires 40-character commit SHAs for third-party actions. |
| "CI is basically green, only one matrix variant is still running." | All matrix siblings must complete. Partial runs leave broken variant pairs. |

## Red Flags

- Unpinned third-party actions (using `@v1`, `@main` instead of SHA)
- Adding `e2e.yml` as a required pull-request status check
- Modifying release gates or promotion steps in `build.yml` or `publish.yml`
- Asserting CI passed when checks are still in progress

## Verification

- [ ] `just check-publish-workflow` passes
- [ ] `just test-render-card` passes
- [ ] All modified workflow files pass YAML linting and schema validation
- [ ] Third-party actions are pinned to full commit SHAs with version comments
- [ ] PR description specifies local checks run vs CI status

## References

- [`docs/ci.md`](../../../docs/ci.md)
- [`.github/workflows/`](../../../.github/workflows/)
- [`Justfile`](../../../Justfile)
