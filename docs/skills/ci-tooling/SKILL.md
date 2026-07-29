---
name: ci-tooling
description: Dakota GitHub Actions plumbing — reusable-workflow permission ceilings, App-token requirements, action pinning policy, BuildStream CI config generation, and host cache directories. Load when a workflow fails before its real work starts.
---

# CI Tooling

## Overview

Most Dakota CI failures that are not build failures are plumbing: the token
budget a caller hands to a reusable workflow, which token can push what, how
`buildstream-ci.conf` is generated, and which host directories must exist
before a podman bind-mount. This skill covers the layer beneath the build.

## When to use

- A run produced no jobs, or a reusable-workflow call job never started
- A step failed on permissions, missing secrets, or a token that cannot push
- Changing `.github/actions/generate-bst-ci-config` or remote-cache settings
- A podman step fails with a missing bind-mount source directory
- Adding or updating an `uses:` reference

## When not to use

- Deciding which domain owns the failure → [ci-triage](../ci-triage/SKILL.md)
- Boot-check, smoke, or testsuite failures → [e2e-ci](../e2e-ci/SKILL.md)
- Queue entry and required checks → [merge-queue](../merge-queue/SKILL.md)

## Authoritative sources

- `.github/actions/generate-bst-ci-config/action.yml` — writes both BST configs
- `.github/actions/check-bst2-pin/action.yml` — bst2 image pin consistency
- `.pre-commit-config.yaml` — the two executable action-pinning rules
- `Justfile` — the `bst`, `sbom`, `export`, and `lint` recipes CI invokes

## Workflow

1. **Read the caller's top-level `permissions:` first.** It is the ceiling for
   the whole reusable chain; a job-level block can narrow it but never widen
   it. Match the caller's block to the union of what every nested job needs.
2. **Pick the right token for the job.** `GITHUB_TOKEN` cannot push changes to
   files under `.github/workflows/`, and events it creates do not trigger
   further workflow runs. Automation that edits workflow files or opens PRs
   that must be checked uses the Mergeraptor GitHub App token instead.
3. **For BuildStream jobs, choose the config mode, not the config text.** The
   generator takes `enable-remote-execution` and `enable-push` and emits
   `buildstream-ci.conf` plus a separate push-only `buildstream-push.conf`.
   The x86_64 build keeps pushing off during the build and pushes artifacts in
   a dedicated step afterwards; export-only jobs disable both. Read the
   action's inline rationale before changing either input.
4. **Create host directories before bind-mounting them.** `actions/cache`
   restores archive contents but does not create the path on a cold miss, and
   podman refuses to start when a bind-mount source is absent. The `Justfile`
   recipes `mkdir -p` every cached path they mount for exactly this reason.
5. **Pin new actions per the pre-commit rules** — external actions by full
   commit SHA with a version comment, `projectbluefin/*` refs by managed tag.
   Both directions are enforced as commit-time hooks; do not work around them.

## Failure modes

### Storage-service placement changes casd's mode

The generated config only nests `storage-service:` inside the
`remote-execution:` block, and only emits a top-level `cache.storage-service`
when pushing is enabled. Adding a top-level storage service to a
remote-execution build routes every casd operation through the remote cache
and turns transient blob transfers into one sustained gRPC stream. The
rationale is written beside the code that emits each block.

### Errexit swallows a failure inside a command substitution

`run:` steps execute under `bash -e`, so `VAR=$(cmd)` aborts the step before
any `rc=$?` handling. Where a workflow needs to inspect a non-zero exit and
continue with a warning, it wraps the assignment in `set +e` / `set -e`.

### Reusable-workflow inputs are validated at graph time

A `with:` key the target workflow does not declare in
`on.workflow_call.inputs` fails the run before any job exists, and actionlint
does not catch it. Read the target workflow's input list, not the caller's
expectations.

### An expression that reads an absent context

Contexts differ per event — `inputs` does not exist on a `workflow_run`
trigger. A bare `if:` expression tolerates the missing context; wrapping the
same reference in `${{ }}` evaluates it during graph validation and fails the
run outright.

## Verification

```bash
# Caller permission ceilings
rg -n -A8 '^permissions:' .github/workflows

# Which jobs use the BST config generator and in which mode
rg -n -A4 'generate-bst-ci-config' .github/workflows

# Action pinning rules are enforced at commit time
pre-commit run no-floating-action-tags --all-files
pre-commit run no-sha-pins-for-internal-actions --all-files

# Did the run create jobs?
gh run view <id> --repo projectbluefin/dakota --json conclusion,jobs
```

## Related skills

- [ci-triage](../ci-triage/SKILL.md) — decide the domain before debugging here
- [e2e-ci](../e2e-ci/SKILL.md) — gates that run after the image exists
- [merge-queue](../merge-queue/SKILL.md) — required checks and automation PRs
- [release-promotion](../release-promotion/SKILL.md) — promotion plumbing
