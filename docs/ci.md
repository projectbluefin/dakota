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
| `build-aarch64.yml` | Manual only; automatic ARM CI paused | Build the decoupled aarch64 image on explicit request |
| `boot-test-aarch64.yml` | Manual only; automatic ARM CI paused | Experimental ARM boot validation; requires KVM |
| `execute-release.yml` | Mon/Wed/Fri 18:00 UTC and manual recovery | Verify and promote the tested x86 variants to `stable` |

PRs do not publish their image, so `e2e.yml` does not run on pull requests: it
would test a stale public tag rather than the PR. Run it manually only after the
intended image is available.

ARM build and boot-test workflows no longer follow publish/build completion.
There is no usable ARM boot-test environment: the configured hosted runner lacks
KVM, which the boot test requires. Keep both workflows manual-only until ARM
boot validation is available. Manual builds still publish/sign ARM images, but
must be followed by a separate explicit boot-test dispatch; a skipped KVM test
is not boot-verification evidence. ARM elements and x86 CI are unchanged.

GitHub's [manual workflow documentation](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
describes `workflow_dispatch`; the workflow must exist on the default branch.

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

## Next synchronization

`sync-next.yml` synthesizes `next` from `testing`, restores `NEXT_OWNED` paths,
and three-way merges `NEXT_MERGED` files. Divergence outside those lists or a
merge conflict stops the sync before its lease-protected push.

Kernel recipes, patches, OGC fragments and vendored FDSDK configuration helpers
remain next-owned. `files/linux/dakota-config.sh` is shared: capability fixes
flow from testing without replacing next's kernel versions. Do not mark all of
`files/linux` next-owned, which would silently retain stale capability settings.

Keep unrelated dependency additions away from next-only replacement blocks in
`NEXT_MERGED` files (for example, the BPF dependencies in `bluefin/deps.bst`).
Even an insertion adjacent to a replacement can conflict. Moving that insertion
on `testing` without changing the dependency set can unblock the merge without
changing next's SDK overlay. Check all merged files against the current branch
tips; do not resolve these conflicts by blindly choosing either entire file or
by expanding `NEXT_OWNED`, which would prevent testing updates flowing through.

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
