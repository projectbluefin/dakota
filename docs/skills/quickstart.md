---
name: quickstart
description: Zero-context Dakota maintenance guide. Use when doing routine add/remove/update work and you need the shortest safe path through branch setup, validation, and the factory workflow.
metadata:
  context7-sources:
    - /apache/buildstream
    - /websites/github_en_actions
---

# Quickstart

## Overview

This is the **smallest safe default** for routine Dakota work.
It is not the full reference manual. It is the path that prevents the most common factory mistakes.

## When to Use

Use when:
- adding, removing, or updating a package
- doing small maintenance with little repo context
- you want the standard branch → edit → validate → PR flow

## When NOT to Use

- CI failure needs workflow-specific debugging → CI skills
- complex packaging needs a language-specific skill → `packaging-*.md`
- you are still leaking bluefin habits → `not-bluefin.md` first

## Core Process

1. **Load `not-bluefin.md` if needed.**
2. **Branch from `upstream/testing`.**
3. **Pick the focused skill for the change.**
4. **Use `just` recipes, not ad-hoc host commands.**
5. **Run the lightest validation that proves the change.**
6. **Commit with `Assisted-by:` and update the relevant skill in the same PR.**

## Always Rules

1. **Run the CI pre-flight before any merge, push, or workflow dispatch.** (See Hard Rule #9 in `.github/copilot-instructions.md`.)
2. Run `just --list` first.
3. Use `just bst ...`, not bare `bst`.
4. Grep all references before removing a package or file.
5. Add new package elements to the correct stack.
6. Validate before opening the PR.
7. Push to `upstream`, never the fork.

## Never Rules

1. Never solve package/image-content changes in `Containerfile`.
2. Never open a Dakota PR without validation evidence.
3. Never edit junctions casually; treat them as human-review territory.
4. Never add duplicate automation when an existing recipe or workflow already owns it.
5. Never skip the skill update if you discovered a reusable lesson.

## Task Routing

| Task | Load |
|---|---|
| Add package | `add-package.md` |
| Remove package | `remove-package.md` |
| Update source ref/version | `update-refs.md` |
| Debug element build | `debugging.md` |
| BST syntax/reference | `buildstream.md` |
| CI failure | `ci.md` |

## Default Workflow

```bash
# branch
git checkout upstream/testing -b fix/short-description

# inspect recipes
just --list

# make the change

# validate with the lightest checks that match the scope
just bst show oci/bluefin.bst
just lint

# commit
git commit -m "fix(bluefin): short description

Closes #NNN

Assisted-by: OpenAI GPT-5 via pi"

# push
git push upstream fix/short-description
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll use bare bst just this once." | That's how environment drift sneaks in. |
| "This is small; I don't need validation." | Small changes still waste CI if the graph is broken. |
| "I learned something, but I'll document it later." | Later means never. The factory loop breaks immediately. |
| "The fork is fine for this push." | Not for Dakota's normal upstream PR flow. |

## Red Flags

- Starting from local `testing` instead of `upstream/testing`
- Using host-installed bst or random shell commands instead of `just`
- No evidence attached to the PR
- A skill-worthy lesson discovered but not written back

## Verification

- [ ] Branch started from `upstream/main`
- [ ] Correct focused skill was loaded for the task
- [ ] Validation matched the scope of the change
- [ ] Commit uses repo conventions including `Assisted-by:`
- [ ] Skill update is included when a new pattern was learned

## Lessons Learned

### Rootless podman export/lint on local shells (2026-07-05)

If `just export` or `just lint` fail with `sudo: a terminal is required to read the password`,
the repo recipes are invoking `sudo podman` even though the current user already
has a working rootless podman setup. In that case, run the equivalent podman
commands directly with the same flags as the recipe instead of forcing sudo.
A successful local validation path is:

1. `just validate`
2. `just bst artifact checkout oci/bluefin.bst --directory /src/.build-out`
3. `podman pull -q oci:.build-out`
4. `podman build ... -t dakota:latest`
5. `podman run ... dakota:latest bootc container lint`

This is a local-environment workaround, not a repo change.

### Restarting the publish factory after a pause (2026-06-05)

When publishing has been intentionally paused (e.g., post-repo-refactor), the
factory restart sequence is:

1. Fix any `startup_failure` in `publish.yml` — check for invalid `permissions:` scopes
   (e.g. `artifact-metadata: write` is not a valid GITHUB_TOKEN scope) and
   job-level `permissions:` on reusable workflow call jobs.
2. Dispatch `build.yml --ref testing` to populate the remote CAS.
3. Wait ~60–90 minutes for the build to complete.
4. `publish.yml` auto-triggers via `workflow_run`. If not, dispatch manually.
5. Once `:testing` lands, `execute-release.yml` auto-triggers to promote `:testing` → `:stable` (no human approval needed).

Full details: `release-promotion.md` and `ci-tooling.md`.

### When a remote build is slow, verify RE is actually active before changing workflows again (2026-07-06)

If a Dakota remote build is slow or times out, do not start by toggling the same workflow flag again. First verify that the workflow still passes the correct inputs to the config generator and that the generated BuildStream config actually contains a `remote-execution:` block. The 2026-07-06 investigation showed that cache access alone can be present while expensive build actions are still happening locally on the runner.

**Current state:** The tracked `build.yml` still calls the generator with `enable-remote-execution: "false"`, so the current CI path is runner-local / cache-only and noncompliant. A slow build today is expected to fail the RE evidence checks below until the workflow and generator are fixed.

The required RE fail-fast checklist for the next run is:

1. Confirm `build.yml` still sets `enable-remote-execution: 'true'`.
2. Confirm the generated `buildstream-ci.conf` includes a `remote-execution:` section with the remote CAS endpoint.
3. Confirm BuildStream startup reports "Remote Execution Configuration" in the build log.
4. Confirm live BuildBarn worker actions are observed on scheduler-selected workers:
   - `Waiting for the remote build to complete` in BuildStream logs, or
   - BuildBarn worker logs showing `Action:` lines (see the RE backend lesson in `ci.md`).
5. Only after 1–4 are satisfied, inspect the uploaded BuildStream logs for `Pulled artifact`, `Pulled source`, and `does not have artifact/source cached` lines to confirm cache activity.
6. If RE is verified active and the build still runs long, treat the next bottleneck as an actual build / upstream-cache issue and inspect the active element graph rather than another workflow-only change.

A run that satisfies 1–2 but not 3–4 is in cache-only / runner-local mode. That is an unacceptable operational state for Dakota; do not extend timeouts or merge until RE is restored and proven.

This keeps the work evidence-first and leaves the next run with a concrete verification path instead of another round of blind churn.
