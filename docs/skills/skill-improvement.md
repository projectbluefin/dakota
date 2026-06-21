---
name: skill-improvement
description: "The skill-improvement mandate for this repo. Every session produces work + a skill file update. Use when completing a task, deciding whether a learning belongs in docs/skills, or verifying the work+learning loop before handoff."
metadata:
  type: procedure
---

# Skill Improvement Mandate

Every agent session produces two outputs:

1. **The work** — the PR, fix, or feature
2. **The learning** — what a future agent needs to know

Output 1 without Output 2 leaves the factory no smarter.

## When to Use

Use when finishing any Dakota task, deciding whether a discovery belongs in `docs/skills/`, or reviewing a branch for factory-memory completeness before handoff.

## When NOT to Use

- You are still routing the task to the correct domain skill → start with `README.md` or the focused skill in `docs/skills/README.md`
- You need implementation details for a specific subsystem → load the narrow domain skill first, then come back here before closing the work
- You are writing ephemeral session notes, personal scratch work, or changelog-style narration — those are banned here

## Core Process

1. Identify what changed and what you had to learn to make it work.
2. Decide whether that learning is durable, non-obvious, and likely to help the next agent.
3. Route the learning to the narrowest existing skill file; create a new skill only if no focused home exists.
4. Add the learning in the same branch/PR as the implementation so the factory gets both outputs together.
5. Verify the updated skill contains concrete triggers, failure patterns, and checkable exit criteria before you mark the task done.

## Before Marking Work Done

- [ ] Discovered a workaround, non-obvious pattern, or convention?
- [ ] Is there a skill file for the area worked in?
- [ ] If yes — updated it?
- [ ] If no — created one?
- [ ] Skill file committed in **this same PR**?

## What Counts

Write it: upstream bug workarounds, non-obvious correctness requirements, trial-and-error discoveries, common failure modes.

Do NOT write it: one-off task notes, ephemeral state, session logs, things obvious to any developer.

## Where

All learnings → `docs/skills/` in this repo. Cross-cutting patterns affecting 2+ repos → open issue in `projectbluefin/common` with `kind/improvement` + `area/agent`.

## What Is Banned

- No changelog files (`IMPROVEMENTS.md`, `CHANGELOG.md` for agent notes, `SESSION.md`, etc.). Delete them if found.
- No session notes committed to the repo.
- No "append here" instructions. Route to a specific `docs/skills/<file>.md`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This fix was obvious once I found it." | If you had to discover it, the next agent will too. Write it down. |
| "I'll update the skill later in a follow-up PR." | The loop breaks if work and learning ship separately or not at all. |
| "A giant catch-all note is good enough." | Route to the narrowest skill so future agents can actually find it. |
| "This only affected CI/docs, so it doesn't need a skill update." | Operational patterns are exactly what skills are for. |
| "The rule already exists in AGENTS.md, so I can skip the local skill." | AGENTS carries hard rules; the task-specific workflow and examples belong in the focused skill. |

## Red Flags

- A branch changes behavior but touches no relevant skill file
- Learnings are written as session logs instead of reusable guidance
- A new pattern gets stuffed into an unrelated catch-all file
- The same mistake recurs across sessions because nobody wrote back the workaround
- Task completion claims success before the work+learning loop is checked

## Verification

- [ ] The task produced both implementation work and any durable learning it uncovered
- [ ] The learning was routed to the narrowest relevant skill file
- [ ] No ephemeral notes or changelog-style scratch files were added to the repo
- [ ] The updated skill gives future agents concrete triggers, anti-patterns, and exit criteria
- [ ] The branch is not marked done until the skill contribution check passes

Full mandate: [`projectbluefin/common/docs/skills/skill-improvement.md`](https://github.com/projectbluefin/common/blob/main/docs/skills/skill-improvement.md)
