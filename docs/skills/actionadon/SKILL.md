---
name: actionadon
description: How Dakota issue lifecycle automation actually moves an issue, which labels gate which transition, and where the gates can be bypassed. Load when triaging, queueing, or claiming an issue, or when changing issue-lifecycle automation.
---

# Issue Lifecycle Automation

## Overview

Two workflows share the issue tracker. `.github/workflows/actionadon.yml` is repo-local
and owns the lifecycle labels and the slash commands. `.github/workflows/bonedigger.yml`
calls a SHA-pinned reusable workflow that handles donated-agent routing and
confirm-driven priority escalation.

An issue's state is the set of labels on it plus the comments under it. Read those
directly — do not infer state from prose in the issue body, and do not restate label
state in a comment.

## When to use

- Triaging, queueing, or claiming an issue
- Working out why an issue will not move to the next state
- Changing either lifecycle workflow

## When not to use

- Pull request labels, review flow, and required checks → [pr-review](../pr-review/SKILL.md)
- A PR that will not enter or clear the queue → [merge-queue](../merge-queue/SKILL.md)
- What the donated evidence means and the privacy contract behind it →
  [`feedback-loop.md`](../../feedback-loop.md)

## Authoritative sources

- `.github/workflows/actionadon.yml` — label creation, transitions, slash commands, sweep
- `.github/workflows/bonedigger.yml` — pins the reusable lifecycle workflow; resolve the
  pinned SHA and read that workflow before assuming any behavior it owns
- `.github/ISSUE_TEMPLATE/*.yml` — labels stamped at creation. These are synchronized
  from their source repository; report needed changes there, never edit them here
- `files/just-overrides/default.just` — the `file-issue`, `confirm`, `verify`, and
  `probe` recipes users run

## How an issue moves

1. **Creation stamps the first labels.** Each template applies its own; the local
   workflow adds `status/discussing` only when no `status/*` or `flow/agent-donation`
   label is already present. An issue that arrives with a triage label therefore sits
   there until a human moves it — nothing promotes it automatically.
2. **A maintainer applies `status/approved`.** The bot replies asking for acceptance
   criteria in the issue body. Approval alone does not open the issue for work.
3. **A wrangler or write-access user comments `/ready`.** This is the real queue gate:
   it requires `status/approved`, a dedicated `### Acceptance criteria` section in the
   body, and at least one checklist item inside it. Passing all three adds
   `status/queued`. The wrangler list is an environment variable in the workflow.
4. **Anyone comments `/claim`.** This requires `status/queued` and refuses if the issue
   is already claimed. It swaps `status/queued` for `status/claimed` and assigns the
   commenter.
5. **`/unclaim` returns it.** Allowed for the assignee, a wrangler, or write access.
   It restores `status/queued` and unassigns.
6. **The scheduled sweep reclaims stalled work.** Claimed issues with no update for
   seven days are unassigned and returned to the queue.

Donated-agent issues skip the queue gate: both workflows route them to a flow label
derived from the URL in the body and queue them on creation. They end in a sourced
report comment and a close, not a pull request.

## Failure modes

- **The acceptance-criteria gate is only on `/ready`.** Applying `status/queued`
  directly as a label bypasses the body and checklist checks entirely, and `/claim`
  accepts the result. If a queued issue has no acceptance criteria, it was labelled by
  hand — get the criteria written before starting work rather than inventing them.
- **Confirm counting is stricter than it looks.** Priority escalation counts only
  comments whose body *begins* with `ujust confirm <this issue number>`. A confirmation
  posted through the `ujust confirm` recipe opens with a heading instead, so the count —
  and therefore the priority label — can stay at zero while real confirmations exist.
  Count the comments yourself before treating a missing `priority/*` label as evidence
  that nobody else hit the bug.
- **Closure has no automation behind it.** No workflow counts verifications or closes
  anything. The verification threshold is a project commitment described in
  [`feedback-loop.md`](../../feedback-loop.md), enforced by people.
- **Slash commands drift from template prose.** The workflow implements `/claim`,
  `/unclaim`, and `/ready`. Any other command mentioned in a synchronized template is
  not handled here; check the workflow before telling a contributor to use one.
- **Restating label state in a comment.** The labels and the linked report are already
  visible. A status comment adds noise to every subscriber's inbox and to the next
  agent's context.

## Verification

```bash
# Current label state and assignment for an issue
gh issue view <N> --repo projectbluefin/dakota --json labels,assignees,state

# Raw comment bodies — read these before trusting any derived label
gh issue view <N> --repo projectbluefin/dakota --json comments --jq '.comments[].body'

# Which transitions and commands the local workflow actually implements
rg -n 'startsWith\(github.event.comment.body|add-label|remove-label' \
  .github/workflows/actionadon.yml

# The pinned reusable workflow behind the second automation
rg -n 'uses:' .github/workflows/bonedigger.yml
```

## Related skills

- [pr-review](../pr-review/SKILL.md) — the review flow an issue's fix lands through
- [ujust-recipes](../ujust-recipes/SKILL.md) — the recipes users run to produce evidence
