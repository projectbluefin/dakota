---
name: ci-triage
description: First response to any Dakota CI failure — locate the failing run, decide whether it is plumbing, build, boot, queue, or release, and hand off to the narrow skill that owns it. Load before reading CI logs.
---

# CI Triage

## Overview

Dakota's CI is a set of independent workflows coupled only by `workflow_run`
listeners and one shared concurrency group. Triage means finding which link
broke and which domain owns it — before reading logs or dispatching anything.
Inspect `.github/workflows/` for current triggers; this skill does not mirror
them.

## When to use

- A workflow run failed, was skipped, or never appeared at all
- An expected image tag did not move
- You are about to re-dispatch a workflow and need to know whether that helps

## When not to use

- A BuildStream element fails to compile → [debugging](../debugging/SKILL.md)
- You already know the domain → go straight to the skill in the routing table

## Authoritative sources

- `.github/workflows/` — every trigger, filter, and job condition
- `Justfile` — the local reproduction recipes CI itself calls
- `scripts/check_publish_workflow.py` — executable guard on the boot-check step

## Workflow

1. **Find the run and check whether it created jobs.**
   `gh run view <id> --repo projectbluefin/dakota --json conclusion,jobs`.
   An empty `jobs` array means the workflow file was rejected before any job
   existed — that is plumbing, not build logic.
2. **Decide whether the run should exist at all.** Downstream workflows
   subscribe to the upstream workflow's `name:` string, not its filename.
   Renaming a workflow silently detaches every listener: nothing fails, the
   chain just stops. Confirm the subscription still resolves before assuming
   a bug in the workflow you are reading.
3. **If a run is queued but idle, check the shared build concurrency group.**
   Several workflows serialize on `dakota-bst-build-global` with
   `cancel-in-progress: false`, so an in-flight BuildStream run holds every
   other one back. That is the design, not a stuck queue.
4. **Route to the owning skill** using the table below, then stop triaging.
5. **Pull the artifacts before the logs expire.** Build jobs upload
   BuildStream logs on every run, not only on failure; the boot-check job
   uploads the VM serial log the same way. Both are `if: always()` uploads on
   their respective jobs.
6. **Reproduce at the cheapest tier that covers the failing stage** —
   `just validate`, then `just build`, `just lint`, `just boot-test`.

### Routing table

| Symptom | Owning skill |
|---|---|
| No jobs created, permission/token error, cache or BST config problem | [ci-tooling](../ci-tooling/SKILL.md) |
| Element failed to compile or the build timed out | [debugging](../debugging/SKILL.md) |
| Image built but boot-check, smoke, or testsuite failed | [e2e-ci](../e2e-ci/SKILL.md) |
| PR cannot enter the queue, or an automation branch is stale | [merge-queue](../merge-queue/SKILL.md) |
| A stream tag published but `:stable` did not move | [release-promotion](../release-promotion/SKILL.md) |
| `:aarch64` or the multi-arch manifest is missing | [aarch64](../aarch64/SKILL.md) |

## Failure modes

### Scheduled runs execute the default branch's workflow file

GitHub runs `schedule:` events against the repository default branch only.
`build.yml` therefore hard-fails a `verify-default-branch` job when the
default branch is not `testing`, and the `next` stream needs its own
dispatcher workflow instead of a second `schedule:` entry. A silent "wrong
branch got built" is the failure this guard exists to prevent.

### A successful build that publishes nothing is often correct

The publish workflow derives the stream tag from the branch and leaves it
empty for merge-queue refs, which publish an immutable `:SHA` tag only. Read
the tag-derivation step before concluding that promotion is broken.

### Re-dispatching before the upstream artifact exists

Publish jobs export the image from the remote CAS rather than rebuilding it.
Dispatching publish for a SHA that was never built produces a confusing
export failure, not a rebuild. Build first, then let the chain run.

## Verification

```bash
# Recent runs and their conclusions
gh run list --repo projectbluefin/dakota --limit 10

# Did this run produce jobs at all?
gh run view <id> --repo projectbluefin/dakota --json conclusion,jobs

# Which workflows subscribe to which upstream workflow name
rg -n -A3 'workflow_run:' .github/workflows

# Which workflows share the global build lock
rg -n 'group: dakota-bst-build-global' .github/workflows
```

## Related skills

- [ci-tooling](../ci-tooling/SKILL.md) — plumbing failures before build logic runs
- [e2e-ci](../e2e-ci/SKILL.md) — boot-check, smoke, and testsuite gates
- [merge-queue](../merge-queue/SKILL.md) — queue entry and automation branches
- [release-promotion](../release-promotion/SKILL.md) — promotion to `:stable`
