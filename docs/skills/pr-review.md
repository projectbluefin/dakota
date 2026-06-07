---
name: pr-review
description: Consolidated review workflow for dakota pull requests. Covers review priorities, common rejection reasons, dep-update PR review, and ghost (agent-assisted PR) handling. Load when asked to review any PR in projectbluefin/dakota.
---

# PR Review

Consolidated review workflow for dakota pull requests.

## Before you review

1. Read [`docs/workflow.md`](../workflow.md) — issue lifecycle, labels, branch flow
2. Read [`docs/pr-checklist.md`](../pr-checklist.md) — per-category checklist

## Review priorities (in order)

1. **Branch hygiene** — PR must branch from `upstream/main`, not a fork's local `main`. Verify with `git diff upstream/main...HEAD --stat` — it should be minimal and contain only the PR's changes.
2. **Checklist compliance** — verify the relevant items from `pr-checklist.md` for the type of change (junction bump, patch, OCI, element, etc.).
3. **CI gate status** — `validate` and `e2e` are required status checks. If CI hasn't run, note it. If `e2e` was skipped (non-image paths), that counts as passing.
4. **Scope discipline** — one logical change per PR. Junction bumps must not include patch modifications in the same commit.
5. **Correctness** — element syntax, layer kind (`compose` not `stack`), cargo sources generated not hand-written, systemd units enabled via BST install commands.

## Common rejection reasons

| Signal | What's wrong |
|--------|--------------|
| Hundreds of files in diff | Branched from fork `main` instead of `upstream/main` |
| `kind: stack` in a layer element | Should be `kind: compose` — stack produces zero filesystem output |
| Hand-written crate entries | Must use `generate_cargo_sources.py` |
| Missing `Closes #NNN` | PR isn't linked to an issue |
| `patches/` change in a junction bump commit | Must be separate commits or separate PRs |
| No `just lint` / `just boot-test` evidence | Verification gate not met |

## How to give feedback

- **Guide, don't just reject.** Point contributors toward the correct pattern in `docs/workflow.md` or `docs/pr-checklist.md`.
- **One comment per review event.** Combine all findings into a single review comment. Never post follow-ups for new observations — edit the existing comment.
- **Do not duplicate GitHub UI.** Don't restate approval counts, merge queue status, or CI summaries that GitHub already shows.
- **Minimal test reports.** What ran, pass/fail, blockers. No diff summaries.

## Ghost detection

Agent-assisted PRs are identified by the checked template checkbox:
`[x] I am using an agent and I take responsibility for this PR`

Hold these to the same standard as human PRs. The operator is accountable.

## Mergeraptor pre-approval

Junction-only bumps from `mergeraptor[bot]` are pre-approved once `validate` and `e2e` pass (or e2e is skipped for non-image paths). No human review required for those.

## Dep-update PR review

Auto-generated dep-update PRs (`auto/track-*`, `renovate/*`) always target
`main` by default. Before reviewing, check:

1. **Is it redundant?** — Compare the `ref:` field in the element against
   `upstream/testing`. If identical, close the PR; `testing` already has it.
2. **Cherry-pick, don't merge as-is** — The branch is based on `main` and
   carries 4–6 unrelated CI/docs commits not in `testing`. Cherry-pick only
   the top dep-update commit onto a clean `testing` base.
3. **Skip e2e if infrastructure is broken** — If the same e2e failure appears
   on every dep PR simultaneously ("SSH never became ready"), it's a stale
   `:testing` issue, not a PR issue. Validate passing + correct diff is enough.

See `merge-queue.md` for the full retarget/cherry-pick/merge flow.

## Lessons Learned

### Rubber duck CI changes against bluefin/bluefin-lts before merging (2026-06-07)

When making changes to `.github/workflows/` that touch the publish, promote,
or release pipeline, run a rubber duck comparison against the equivalent
workflows in `projectbluefin/bluefin` and `projectbluefin/bluefin-lts` before
opening a PR. This surfaces inconsistencies and cross-repo bugs that pure
code review misses.

**What to compare:**
- `cert-identity-regexp` anchoring — must be `^...$` end-anchored (dakoa is correct; bluefin/lts are not)
- `environment: production` gate placement — should be on image **promotion**, not on release notes creation
- SBOM handling — artifact-first with Syft fallback is stronger than always regenerating
- TOCTOU patterns — digest-pinned promotions, single skopeo inspect calls

**Invocation:**
```
rubber duck the release pipeline for consistency with projectbluefin/bluefin and bluefin-lts, built on projectbluefin/actions
```

Then pipe the findings directly into fixes before the PR lands. This session
caught 4 issues from rubber duck + 1 interaction bug (TOCTOU guard) from
doublecheck — all fixed before merging.

---
