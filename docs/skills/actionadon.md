# Actionadon Lifecycle and Data Donation

Load when working on any GitHub issue in this repo, triaging bugs, processing the queue, or touching `.github/workflows/actionadon.yml`.

## When to load this skill

Load when: working on any GitHub issue in this repo, triaging bugs, processing the queue, or touching `.github/workflows/actionadon.yml`.

## The data donation contract

Dakota's bug reports are not bug reports. They are data donations. A user running `ujust report` deliberately captures and shares their system state. This is the ground truth that makes from-source OS development tractable. Agents working in this repo must understand this contract and never devalue it.

**The automation ratio**: without `ujust report`, fixing one bug requires 5+ comment cycles: kernel version, hardware, logs, reproducible, always. With a gist-backed report, the maintainer has everything before the first reply. The pipeline widget makes this visible to the reporter so they know their donation landed and is moving.

## Pipeline stages and what each means for agents

```text
<!-- actionadon-pipeline -->
DAKOTA  ·  issue pipeline
─────────────────────────────────────────────────
  ✓  filed      report received
  ✓  approved   cleared for the build queue
  ▶  queued     open for contributors
  ·  claimed    —
  ·  done       —
─────────────────────────────────────────────────
  report:       attached    ·  confirms: 2
  area:         hardware    ·  priority: high
  verified:     0/3         ·  next action: comment /claim to take this
```

| Stage | Widget line | Trigger | Agent action |
|---|---|---|---|
| `filed` | `✓ filed` or active `▶ filed` | Issue opened. `status/triage` applied. | Do not claim. Wait for human triage. If `report: missing`, do not interrogate the reporter. They may not have run `ujust report` yet. If the issue is vague, link them to `ujust report`. |
| `approved` | `✓ approved` or active `▶ approved` | Maintainer adds `status/approved`. Actionadon also adds `status/queued`. | Human review is complete. Agent may `/claim` once the issue is actually in queue. |
| `queued` | `▶ queued` | `status/queued` present. Issue is in the contributor pool. | Comment `/claim` to take it. Check `confirms:` first. Higher count means broader hardware impact. |
| `claimed` | `▶ claimed` | `/claim` comment assigns the issue and adds `status/claimed`. | You own it. Build, test, open the PR. Comment `/unclaim` if blocked. Seven days of inactivity auto-releases it. |
| `done` | `▶ done` or closed issue | Issue closed after the fix ships. | Do not reopen. Read `verified: N/3` as post-ship hardware confirmation. If below target, flag for human decision instead of acting unilaterally. |

## Widget sentinel rule

The sentinel `<!-- actionadon-pipeline -->` marks the managed block at the top of every issue body. Agents must never:

- Remove or edit the sentinel block manually
- Post a comment that duplicates the pipeline state. The widget is the state.
- Close an issue without checking `verified:`. Target is `3/3`. Below that, flag for human decision.

## Reading the metadata rows

| Row | What it tells you |
|-----|-------------------|
| `report: attached` | Full gist telemetry exists. Check it before asking any question. |
| `report: missing` | No gist yet. The issue may be less actionable. |
| `confirms: N` | `N` people hit this on distinct hardware. Use it as a blast-radius proxy. |
| `verified: N/3` | `N` people confirmed the fix on real hardware after ship. |
| `area:` | Subsystem from labels. Scope your fix accordingly. |
| `priority:` | Urgency from labels. |

## Slash commands

| Command | Who | Effect |
|---------|-----|--------|
| `/claim` | anyone | Assigns you, adds `status/claimed`, advances the widget |
| `/unclaim` | assignee or write+ | Returns the issue to the queue |
| `/approve` or `/lgtm` | write+ | Adds `lgtm`, auto-queues |

## Hive exempt labels

Do not touch issues with: `hold`, `do-not-merge`, `status/discussing`, `status/claimed` (if you are not the assignee), `agent/blocked`, `needs-human/agent-oops`.
