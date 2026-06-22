---
name: skills-index-factory
description: Factory-standard index for Dakota's docs/skills/. Points to the full routing table in README.md. Load when onboarding to this repo or auditing factory compliance.
metadata:
  type: index
---

# docs/skills — Factory Index

> **Full routing table and fast paths:** [`README.md`](README.md)

This repo's skill directory follows the `projectbluefin/common` factory standard.

## Factory Compliance Checklist

- [x] `skill-improvement.md` — two-output mandate, banned anti-patterns
- [x] `README.md` — full routing table with fast paths per task class
- [x] AGENTS.md — self-improvement loop, banned list, hard rules

## What Belongs Here

Workflow knowledge, architectural patterns, and operational runbooks that any agent needs to work effectively in this repo.

**Not here:** agent-specific instruction files (`.github/copilot-instructions.md`, `AGENTS.md`) — those are loaded separately by their respective tools.

## Cross-Repo Skill Home

| Repo | Skill home |
|---|---|
| `projectbluefin/dakota` | This directory |
| `projectbluefin/common` | [`common/docs/skills/`](https://github.com/projectbluefin/common/tree/main/docs/skills) |
| Cross-cutting patterns | Open issue in `projectbluefin/common` with `kind/improvement` + `area/agent` |

## Self-Improvement Standard

Source: [`projectbluefin/common/docs/skills/factory-onboarding.md`](https://github.com/projectbluefin/common/blob/main/docs/skills/factory-onboarding.md)

Every skill file must have:
- Frontmatter: `name` + `description` with "Use when" trigger phrases
- `## When to Use`
- `## When NOT to Use`
- `## Core Process` (numbered workflow)
- `## Common Rationalizations`
- `## Red Flags`
- `## Verification`
