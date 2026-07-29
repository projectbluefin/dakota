---
name: pr-review
description: Review order for Dakota pull requests and the per-change-type checks that catch the defects CI cannot. Load when reviewing a PR in projectbluefin/dakota or preparing a branch for maintainer review.
---

# PR Review

## Overview

Review in cost order: the checks that invalidate a whole branch come first, the ones
that need reading the diff come last. CI answers structural questions (`Validate`), so
a review that repeats them adds nothing; spend the attention on the classes of defect
that build and merge cleanly and only fail on a deployed system.

## When to use

- Reviewing any pull request in `projectbluefin/dakota`
- Self-checking a branch before requesting maintainer review

## When not to use

- A PR that will not enter or clear the queue → [merge-queue](../merge-queue/SKILL.md)
- Interpreting a red check → [ci-triage](../ci-triage/SKILL.md)
- Issue triage before a PR exists → [actionadon](../actionadon/SKILL.md)

## Authoritative sources

- `.github/workflows/pr-triage.yml` — base-branch enforcement, `pr/needs-review`, the
  approval path that enables auto-merge
- `.github/workflows/validate.yml` — the always-on gate and the events it runs on
- `.github/workflows/e2e.yml` — read its trigger before claiming it gated anything
- `.github/CODEOWNERS` — which paths require maintainer review
- `.github/PULL_REQUEST_TEMPLATE.md` — the evidence the author committed to providing
- [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) — branch model, trailers, local checks

## Review order

1. **Base branch.** Content PRs target `testing`; `next` also accepts PRs directly.
   `main` is a release bookmark and `pr-triage.yml` fails any PR aimed at it. Retarget
   rather than reason about the diff — the base determines what the diff even means.
2. **Diff scope.** `git diff <base>...HEAD --stat`. A diff carrying unrelated files
   usually means the branch was cut from the wrong base. One logical change per PR; a
   junction bump must not carry patch edits in the same commit, because the two need
   different verification and revert independently.
3. **Ownership.** Some paths require maintainer review. `.github/CODEOWNERS` decides
   which, and [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) summarizes the boundary for
   contributors. Read the file rather than a remembered list — it also carries
   exemptions for auto-updated paths.
4. **Checks.** Read what actually ran (`gh pr checks`). `Validate` is the always-on gate
   and runs on both PR and queue events. The end-to-end suite is dispatch-only and does
   not run on pull requests, so its absence is not a gap. The docs job is advisory and
   cannot block; a red advisory job still means something is wrong.
5. **Evidence.** The template asks for local build, lint, and boot results. For a change
   that can reach the image, a green `Validate` is not evidence that it boots. If no
   automated check covers the change, the body must say how it was verified by hand.
6. **The diff itself**, using the per-change-type checks below.

## Per-change-type checks

**Junction bumps.** Only the junction element changed. Every patch in the matching
`patches/` directory still applies against the new ref, and any patch the bump makes
redundant is dropped in a separate change → [patch-junctions](../patch-junctions/SKILL.md).

**Patch queue.** The patch's commit message states why it exists and the condition for
dropping it. Filenames sort into the intended application order.

**OCI assembly.** Post-install command order in `elements/oci/bluefin.bst` is
load-bearing and a reordering builds cleanly → [oci-layers](../oci-layers/SKILL.md).

**Elements.** A layer element that must ship files is `kind: compose`; `kind: stack`
aggregates dependencies and emits nothing. New elements are wired into `bluefin/deps.bst`
or they never reach the image, and new files under `files/` need a matching
`install-commands` entry in the owning element. Symlink targets get `mkdir -p` first.
Sources pin a tag or commit, never a moving branch. Crate source blocks are generated
by `files/scripts/generate_cargo_sources.py`, never hand-written. `install-commands` must
be deterministic and offline — no `date`, `hostname`, `whoami`, or network fetches — and
systemd units are enabled by creating the `.wants` symlink at install time, not by a
post-install script.

**Workflows.** Any cosign `--certificate-identity-regexp` is anchored with `^` and `$`
and names one workflow file; an unanchored pattern accepts signatures from any workflow
in the repository. A check that is required by the queue must run on both `pull_request`
and `merge_group` → [merge-queue](../merge-queue/SKILL.md).

**Commits and PR body.** Subjects follow Conventional Commits.
[`CONTRIBUTING.md`](../../../CONTRIBUTING.md) is the authority on the trailer rule —
new commits require `Assisted-by:` and must not use `Co-authored-by:`. Do not rewrite
existing history to change its trailers. `Closes #NNN` belongs in the **pull request
body**: that is what links and closes the issue on merge. It is not required in any
commit message, so its absence from the log is not a finding.

## Failure modes

- **Approving to unblock.** A maintainer's approving review clears the review label and
  hands the PR to auto-merge, which squash-merges it as soon as the required checks pass
  — with a direct squash as the fallback. The review *is* the merge decision; approve
  only when the change should land as-is.
- **Reading the label instead of the timeline.** `pr/needs-review` is re-added on every
  push, so a previously approved PR that got new commits is unreviewed again. That is
  the point of the re-add, not a glitch.
- **Treating a skipped or dispatch-only job as a pass.** Confirm which event a workflow
  runs on before concluding it validated the branch.
- **Reviewing an automation branch as if a human wrote it.** `auto/track-*` branches are
  recreated by their tracker; hand-fixing one is discarded on the next run.

## Verification

```bash
gh pr view <N> --repo projectbluefin/dakota --json baseRefName,files,mergeStateStatus
gh pr checks <N> --repo projectbluefin/dakota
git diff origin/testing...HEAD --stat        # scope
rg -n '^kind:' elements/oci/layers/*.bst     # layer kinds
```

## Related skills

- [merge-queue](../merge-queue/SKILL.md) — getting an approved PR merged
- [patch-junctions](../patch-junctions/SKILL.md) — junction and patch review detail
- [oci-layers](../oci-layers/SKILL.md) — image assembly invariants
- [update-refs](../update-refs/SKILL.md) — what version-bump PRs are changing
