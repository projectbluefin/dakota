---
name: dakota-review
description: Review Dakota pull requests and work with issues, data-donation reports, labels, and contributor workflow.
---

# Dakota review and issue workflow

## Before reviewing a PR

1. Read [`docs/workflow.md`](../../../docs/workflow.md) and
   [`docs/pr-checklist.md`](../../../docs/pr-checklist.md).
2. Compare the branch against `upstream/testing` unless the PR explicitly
   targets `next`.
3. Identify the change category and apply only its relevant checklist.
4. Inspect required checks without treating pending or skipped work as proven.
5. Review correctness after branch hygiene, scope, and test evidence.

Priorities: minimal diff, one logical change, correct target branch, appropriate
checks, then implementation details.

## Issue evidence

- Work from scoped `status/queued` issues and respect existing ownership.
- Do not act on `hold`, `do-not-merge`, or open design discussions.
- If the issue widget says `report: attached`, read the linked user-owned report
  before asking for additional logs.
- `confirms: N` indicates real-hardware breadth. `verified: N/3` is post-ship
  evidence and cannot be replaced by CI.
- Do not close a shipped issue with no hardware verification without explicit
  maintainer direction.

## GitHub communication

- Never post a comment, review, or body edit unless explicitly asked.
- Post at most one combined comment per requested event.
- Do not duplicate checks, approval counts, queue position, or other GitHub UI
  state.
- Test reports state only what ran, pass/fail, and blockers.
- Mention a person only when asking them for a specific action.
- The absolute prohibition on writes to `ublue-os/*` also applies during review.

## Review checks

- Changes use BST rather than RPM/DNF/Containerfile overlays.
- OCI filesystem layers are `compose`, not `stack`.
- Cargo source blocks are generated.
- Third-party actions are SHA-pinned; managed projectbluefin action tags remain
  intentional.
- Commit messages are conventional and use `Assisted-by:`, never
  `Co-authored-by:`.
- Evidence matches the completion claim.

## References

- [`docs/workflow.md`](../../../docs/workflow.md)
- [`docs/pr-checklist.md`](../../../docs/pr-checklist.md)
- [`docs/feedback-loop.md`](../../../docs/feedback-loop.md)
