---
name: actionadon
description: Dakota issue lifecycle and data-donation contract. Use when triaging issues, claiming work, reading the pipeline widget, or touching issue-lifecycle automation.
---

# Actionadon

## Overview

Dakota issues are not just tickets. They are **data donations**.
The pipeline widget, labels, slash commands, and verification counts are how the factory turns user evidence into work the queue can trust.

## When to Use

Use when:
- working from GitHub issues in this repo
- triaging or claiming work
- reading the Actionadon / pipeline widget state
- touching issue lifecycle automation or slash-command behavior

## When NOT to Use

- Reviewing or fixing code after the issue is already fully understood
- Debugging CI or release workflows unrelated to issue lifecycle

## Core Process

1. **Read the widget before acting.**
2. **Treat `report: attached` as ground truth.** Read the report before asking questions.
3. **Respect stage ownership.** Agents build from queued/claimed work; humans approve.
4. **Use slash commands to interact with the queue.** Do not freestyle the lifecycle.
5. **Do not duplicate widget state in comments.** The widget is already the status surface.

## Data Donation Contract

A user who runs `ujust report` intentionally donates system state.
That donation is what makes a from-source desktop factory workable.

Implications for agents:
- if `report: attached`, read it before asking the reporter anything
- if `confirms: N` is high, treat the issue as broader hardware impact
- if `verified: N/3` is low after ship, do not close the loop casually

## Stage Map

| Stage | Meaning | Agent action |
|---|---|---|
| `filed` | Issue exists, not yet queued for builders | do not claim; wait for human triage |
| `approved` | Human review says it is real and should move forward | prepare to pick it up once queued |
| `queued` | Ready for contributors/agents | `/claim` if you are taking it |
| `claimed` | Someone owns it | if not you, leave it alone |
| `done` | Fix shipped, awaiting verification | do not rewrite history; check `verified:` |

## Widget Reading Guide

| Row | Meaning |
|---|---|
| `report: attached` | gist-backed telemetry exists |
| `report: missing` | less evidence; ask for `ujust report` rather than freeform logs |
| `confirms: N` | blast radius proxy across real hardware |
| `verified: N/3` | post-ship confirmation target |
| `area:` | subsystem scope |
| `priority:` | urgency from labels |

## Slash Commands

| Command | Effect |
|---|---|
| `/claim` | assign yourself and move to claimed |
| `/unclaim` | return the issue to the queue |
| `/approve` or `/lgtm` | maintainer approval / queue progression |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just ask the reporter for logs." | If `report: attached`, the logs are already there. Read them first. |
| "I'll claim it even though it's not queued yet." | That bypasses the factory's human approval step. |
| "I'll summarize widget state in a comment." | Noise. The widget already exists for that. |
| "`verified: 0/3` is probably fine if CI passed." | This repo explicitly values hardware confirmation over wishful closure. |

## Red Flags

- Claiming non-queued work
- Ignoring an attached report
- Commenting status that is already visible in the widget
- Reopening or closing issues without checking verification counts
- Touching `hold`, `do-not-merge`, `status/discussing`, or someone else's `status/claimed` issue

## Verification

- [ ] Widget state was read before acting
- [ ] Attached reports were read before asking questions
- [ ] Only queued work was claimed
- [ ] No comments duplicated existing widget state
- [ ] Hardware confirmation state was considered before treating the loop as closed
