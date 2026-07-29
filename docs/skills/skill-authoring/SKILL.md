---
name: skill-authoring
description: How to decide whether a skill change is warranted, and how to add, split, merge, rename, or delete one. Load before writing or restructuring anything under docs/skills/.
---

# Skill Authoring

## Overview

The code is the model. `Justfile`, `.github/workflows/`, `elements/`, `scripts/`,
and `files/` are the only sources of truth for what Dakota does. A skill teaches an
agent **how to inspect or safely change** that code; it never states what the code
currently says. A skill that mirrors code goes stale silently — no validator can
detect a sentence that was accurate last month.

Write a skill so that following it sends the reader to the file, not away from it.

## When to use

- Deciding whether a session's finding belongs in a skill at all
- Adding, splitting, merging, renaming, or deleting a skill
- Fixing a `just docs-check` failure

## When not to use

- Recording what happened in a session — that never belongs in this repository
- Something a code comment, assertion, or CI check can hold instead
- Hard boundaries and human gates → `AGENTS.md`, not a skill

## Authoritative sources

- `scripts/check_docs.py` — the validator; it is the authority on which structure rules
  are machine-checkable, and the rest are reviewer conventions by definition
- `scripts/test_check_docs.py` — the validator's tests; extend these when adding a rule
- [`index.md`](../index.md) — the canonical router every skill must be linked from
- `.github/workflows/docs-hygiene.yml` — CI job that runs the validator and its tests

## Deciding whether to write anything

A skill changes only when the work produced a **durable, non-obvious, cross-file**
finding: something a future agent would otherwise rediscover by trial and error, and
that cannot be encoded closer to the code.

Try these in order and stop at the first one that holds the finding:

1. Change the code so the problem cannot recur.
2. Encode it as a test, a validator rule, or a CI check.
3. Put it in a comment beside the thing it explains.
4. Only when the decision spans several files and none of the above can carry it,
   write it in the narrowest existing skill.

Most changes end at step 1–3 and touch no skill. **That is a correct outcome.**
Do not add filler edits just to say a skill changed; land a skill update only when
the work surfaced durable guidance that still matters after the code, tests, and
comments are correct. When it did, land that skill update in the same branch as the
work that taught it.

Never add, in any file:

- working logs, session notes, retrospectives, or dated narration
- lessons-learned appendices
- plans, audits, roadmaps, or status snapshots
- parity matrices comparing Dakota to another image or repository
- collections of historical incidents, run IDs, or resolved-bug narratives
- restatements of a current recipe, workflow trigger, label set, or element value

An incident is worth a sentence only when the invariant it produced is still live and
cannot be read off the code; then state the invariant, not the incident.

## Review triggers

When a change lands, review — do not reflexively edit — the surfaces below. Reviewing
often ends in "no change needed"; only edit when the existing text has become wrong or
an unrecorded cross-file decision remains.

| What changed | What to review |
|---|---|
| Workflow behavior | the related CI or release skill; delete any claim the workflow no longer backs |
| A command or recipe | `AGENTS.md`, the build and QA docs, and the skill that invokes it |
| An architecture boundary | [`architecture.md`](../../architecture.md) and every skill that depends on that boundary |
| A repeated failure pattern | fix or encode it in code or tests first; add a skill note only if a cross-file decision stays non-obvious |
| An obsolete procedure removed | delete or merge the skill content describing it, in the same change |

`.github/workflows/skill-drift.yml` only triggers on pull requests based on `main`, and
`pr-triage.yml` rejects those, so drift detection does not gate normal work. Treat this
review as a manual step.

## Structure rules

`scripts/check_docs.py` enforces the machine-checkable ones. It fails a change that
breaks any of these:

- The router lives at `docs/skills/index.md`; skills live at
  `docs/skills/<name>/SKILL.md`; flat files directly under `docs/skills/` are rejected.
- Front matter on each `SKILL.md` carries `name` and `description`.
- Each skill module has exactly one H1, and checked documents do not skip heading
  levels.
- Every relative markdown link resolves; every skill is linked from
  [`index.md`](../index.md) and every router link points at a skill that exists.
- A skill stays under 20,000 bytes and 400 lines.
- No banned working-log heading, dated narration, legacy router path, or client-specific
  product name.
- `files/hive/agent-policies/` is exempt from heading checks, including stale-heading
  bans, because those files use comment-style policy headers rather than normal doc
  structure.

The rest are reviewer conventions that no check can catch:

- `<name>` is lowercase and hyphenated, and reads as the task an agent is doing.
- `description` states what the workflow does and when to load it.
- Point at authoritative files by path rather than restating their contents.
- Hitting the size budget is a signal to split or delete, not to compress prose.
- **One canonical source per fact.** If two skills would both explain something, one
  owns it and the other links to it. Nothing detects a fact duplicated across files —
  this is the convention a reviewer has to hold.

## Lifecycle operations

**Add.** Create the directory and `SKILL.md`, write the front matter, add a trigger row
to [`index.md`](../index.md) under the section a reader would scan for it, then run
`just docs-check`.

**Split.** Split when a skill covers two tasks that are never loaded together, or when
it exceeds its budget. Move each half into its own directory, give each its own trigger
row, and cross-link them under `Related skills` so neither half loses the other's
context.

**Merge.** Merge when two skills are always loaded together or repeat the same facts.
Keep the name a reader would search for, fold the other's unique content in, delete the
absorbed directory, remove its router row, and repoint every inbound link.

**Rename.** `git mv` the directory, update front-matter `name` to match, repoint the
router row and every relative link that referenced the old path.

**Delete.** Delete when the procedure is gone, the code made it unnecessary, or nothing
in it is still true. Remove the directory, remove its router row, and repoint or remove
inbound links in the same change — a deletion that leaves a dangling link fails
`just docs-check`.

## Failure modes

- **Router drift.** A new `SKILL.md` that is not linked from the router, or a router row
  pointing at a deleted skill, both fail validation. The router is the only entry point;
  an unlinked skill is invisible.
- **Silent staleness.** Copying a label list, trigger, or command into prose creates a
  second source that no test guards. Cite the file instead.
- **Budget creep by accretion.** Appending to a skill instead of editing it is how a
  skill turns into a log. Replace text; do not stack it.
- **Documenting the fix instead of applying it.** If a rule can be enforced in
  `scripts/check_docs.py`, add the rule and a test there rather than asking readers to
  remember it.
- **Tests that do not exercise tracked files.** The checker reads tracked Markdown via
  `git ls-files`, so its unit tests must build a disposable git repo in
  `.cache/docs-check-tests/` rather than using untracked loose files.

## Verification

```bash
just docs-check        # links, front matter, headings, budgets, router coverage
just test-docs-check   # the validator's own tests
```

Both must pass before the change is committed.

## Related skills

- [pr-review](../pr-review/SKILL.md) — what a reviewer checks before merge
- [actionadon](../actionadon/SKILL.md) — issue lifecycle automation
