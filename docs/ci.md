# CI reference

This is a map, not a historical runbook. Workflow YAML is authoritative when it
disagrees with this page.

## Pipeline

| Workflow | Trigger | Purpose |
|---|---|---|
| `validate.yml` | PR and merge queue targeting `testing`, `next`, or `main` | Workflow checks, patch drift, and default/NVIDIA BST graphs |
| `build.yml` | Relevant pushes to `testing`/`next`, daily 13:00 UTC, manual | Build four x86 variants through remote execution |
| `publish.yml` | Successful build workflow on `testing`/`next`, manual recovery | Export CAS artifacts, publish immutable and stream tags, sign, attest, and attach SBOMs |
| `e2e.yml` | Manual only | Run testsuite suites against an explicitly published image |
| `build-aarch64.yml` | Architecture-specific push/workflow triggers and manual | Build the decoupled aarch64 image |
| `boot-test-aarch64.yml` | aarch64 pipeline trigger | Boot validation for the ARM image |
| `execute-release.yml` | Mon/Wed/Fri 18:00 UTC and manual recovery | Verify and promote the tested x86 variants to `stable` |

PRs do not publish their image, so `e2e.yml` does not run on pull requests: it
would test a stale public tag rather than the PR. Run it manually only after the
intended image is available.

## Build and publish contract

`build.yml` places BuildStream artifacts in the remote CAS. `publish.yml` can
export only artifacts already built for its resolved SHA. Normal flow:

```text
testing/next change → build.yml → remote CAS → publish.yml
                                      └──────→ immutable :SHA
                                               + :testing or :next
```

The build matrix contains default, NVIDIA, gaming, and NVIDIA-gaming variants.
Those siblings intentionally run together; the remote executor is the capacity
limit.

Publish records the pushed digest and passes that receipt between jobs. Signing,
attestation, stream-tag promotion, and verification operate on the resolved SHA
or digest rather than rediscovering mutable tag state.

## Stable release

`execute-release.yml` is scheduled after the daily build window. It resolves the
published testing SHA and digest, skips an already-current release, invokes the
managed release workflow with anchored cosign identity rules, advances the
`main` bookmark, and verifies resulting tags. The testsuite release gate is
currently disabled in workflow configuration; do not describe it as active.

`main` is a release bookmark, not the development branch. `next` and `btw` never
promote to `stable`.

## Operating rules

- Read the workflow at the commit that produced a failure.
- A workflow with no jobs/logs usually failed parsing or validation before job
  creation; inspect syntax and permissions.
- Third-party actions are pinned to full SHAs. Managed
  `projectbluefin/actions@v1` references are intentional exceptions.
- Remote cache access and remote execution are separate; diagnose them
  independently.
- Never report CI as green while required runs are pending or failing.
- Use `just validate` for local graph/configuration validation. Full image build
  and publication evidence come from CI.

Task-specific guidance is loaded on demand from `dakota-ci` or
`dakota-release` under `.agents/skills/`.
