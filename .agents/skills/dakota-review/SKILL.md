---
name: dakota-review
description: Review Dakota pull requests and work with issues, data-donation reports, labels, and contributor workflow.
---

# Dakota Review and Issue Workflow

Review pull requests and issues with high discipline: minimal diff, correct target branch, evidence-based verification, and strict boundaries.

## When to Use

- Performing code or architecture reviews on PRs in `projectbluefin/dakota`
- Triaging issues, user-donated diagnostic gists (`ujust report`), or verification comments
- Enforcing contributor guidelines, PR checklists, and commit hygiene

## When NOT to Use

- Writing code changes or authoring elements → load `dakota-buildstream` or `dakota-packaging`
- Modifying release promotion or signing gates → load `dakota-release`
- Authoring CI workflows → load `dakota-ci`

## Core Process

1. **Verify Target Branch**: Ensure PR targets `testing` (or `next` if explicitly tracking rolling), never `main`.
2. **Review Hygiene & Commits**:
   - Check commit format: `<type>(<scope>): <description>`.
   - Ensure commits use `Assisted-by:`, **never** `Co-authored-by:`.
3. **Inspect Implementation**:
   - Ensure image changes use BuildStream elements (no DNF, RPMs, or Containerfiles).
   - Ensure layer additions use `kind: compose` (never `kind: stack`).
   - Check that third-party GitHub Actions are pinned to full commit SHAs.
4. **Evaluate Evidence**:
   - For bugs, check for attached gists from `ujust report`.
   - Verify that claimed test results were actually executed (`just validate`, `just boot-test`, etc.).
5. **Constructive Feedback**:
   - If asked to post feedback, compose at most one concise, actionable comment.
   - Never restate GitHub UI status (e.g. "checks are passing").

## Invariants

- **PROHIBITION ON `ublue-os/*`**: Never write to any `ublue-os/*` repository under any circumstance. Ask a human to report upstream manually.
- **Commit Trailer Invariant**: Use `Assisted-by:`, never `Co-authored-by:`.
- **Target Branch**: PRs must target `testing`. `main` is a release bookmark.
- **Hardware Evidence Priority**: `verified: N/3` on issues is post-ship proof that cannot be substituted by CI. Do not close bugs without hardware verification or explicit maintainer direction.
- **Communication Etiquette**: Do not post automated comments or review messages unless explicitly commanded by the user.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I should post a comment acknowledging the PR is open." | Unrequested agent comments create noise. Post only when explicitly instructed. |
| "The PR targets `main`, but that's fine since it's the default branch on some repos." | `main` is a protected release bookmark in Dakota. Merging into it breaks release tracking. PRs must target `testing`. |
| "`Co-authored-by:` is standard GitHub syntax." | Dakota repository policy strictly mandates `Assisted-by:`. |

## Red Flags

- Pull requests with `Co-authored-by:` trailers in commit messages
- PRs targeting `main` instead of `testing`
- Suggesting fixes or workarounds inside `ublue-os/*` repositories
- Closing an issue with `report: attached` without checking the gist
- Restating check statuses or queue positions in review comments

## Verification

- [ ] Target branch is confirmed as `testing`
- [ ] Commit messages follow conventional standards and use `Assisted-by:`
- [ ] No RPM, DNF, or Containerfile overlays introduced
- [ ] Layer elements use `kind: compose`
- [ ] `just validate` has been confirmed locally or in CI

## References

- [`docs/workflow.md`](../../../docs/workflow.md)
- [`docs/pr-checklist.md`](../../../docs/pr-checklist.md)
- [`docs/feedback-loop.md`](../../../docs/feedback-loop.md)
- [`AGENTS.md`](../../../AGENTS.md)
