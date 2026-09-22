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
| `execute-release.yml` | Manual dispatch (maintainer-initiated) | Verify and promote the tested x86 variants to `stable` |

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
describes `workflow_dispatch`; the workflow must exist on the default branch,
which is `testing` in Dakota. Scheduled workflows also use that default branch,
not `main`.

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

## PR builds

Adding the `build` label to a same-repo PR queues a full four-variant build in
the shared BuildStream queue, behind any running stream build. Each new push to
a labelled PR queues again; the stale check skips runs a newer push has
superseded. Fork PRs cannot build: they have no cache credentials and a
runner-local build does not finish.

A successful PR build exports each variant and pushes
`ghcr.io/projectbluefin/dakota<suffix>:pr-N`. PR images are unsigned and never
promoted; `bootc switch` to one to try it. `pr-cleanup.yml` deletes the tags
when the PR closes.

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

`testing` is the default branch and integration trunk. `sync-next.yml` derives
`next` from it with the next-stream overlay. Stable promotion selects a published
`testing` commit SHA and promotes its images by digest; it does not build from
`main`, merge into `main` first, or promote the `next`/`btw` streams.

`execute-release.yml` has no schedule. Both the workflow input and the local
recipe default to **preflight only**. The Python helper in `scripts/release.py`
prints the mode, repository, workflow ref, and candidate before dispatching:

```bash
just release          # dispatch remote preflight; no promotion
just release --apply  # explicitly enable stable promotion
```

These commands dispatch `projectbluefin/dakota` at remote `testing`, not the
local worktree or a fork inferred from Git remotes. Preflight resolves testing
HEAD, requires a successful `publish.yml` run for that exact SHA, resolves the
default-image digest, and compares it to `:stable`. Missing publication fails
with a clear error; an already-current stable digest is a successful no-op.
Wait for the selected SHA's build and publish to finish before cutting stable.

Preflight **does not run the reusable promotion workflow**, including its
signature checks and full variant resolution. A green preflight is not proof
that every promotion check passed. On apply, the existing anchored cosign
policy and digest-based promotion remain in place, followed by GitHub release
creation. The testsuite release gate remains disabled in workflow configuration.

For recovery, append `sha=<full-40-character-SHA>` to either command to select
an already-published testing commit instead of testing HEAD. Empty, abbreviated,
malformed, or repeated SHA arguments are rejected before dispatch. This explicit
recovery override bypasses only the successful-publish-run lookup; digest
resolution and apply-time signature checks still run. Without an explicit SHA,
preflight and apply resolve HEAD independently and may select different commits
if testing advances between runs.

Stable promotion neither updates `main` nor requires it to match the promoted
SHA. Post-release verification compares all four `:stable` image digests with
their SHA-tagged candidates, checks `:stable-multiarch`, and retains the existing
stale-branch scan and untagged GHCR cleanup. These checks depend on image
promotion, not a Git branch update; no branch-protection bypass is needed.

`just test-release` runs offline Python tests with a mocked `gh`, including the
real Justfile argument path. It is registered in `check-publish-workflow` so CI
runs it too. Unlike `just release`, it creates no remote workflow run.

```text
merge into testing → build → publish SHA-tagged images
                   └→ sync-next.yml → next (separate rolling stream)

just release → preflight → inspect the run's candidate and result
just release --apply → verify signatures → promote digests to :stable
                                        └→ create GitHub release

ISO: separate dakota-iso workflow consumes :stable (not main)
```

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
