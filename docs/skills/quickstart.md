---
name: quickstart
description: Zero-context Dakota maintenance guide. Use when doing routine add/remove/update work and you need the shortest safe path through branch setup, validation, and the factory workflow.
metadata:
  context7-sources:
    - /apache/buildstream
    - /websites/github_en_actions
---

# Quickstart

## Overview

This is the **smallest safe default** for routine Dakota work.
It is not the full reference manual. It is the path that prevents the most common factory mistakes.

## When to Use

Use when:
- adding, removing, or updating a package
- doing small maintenance with little repo context
- you want the standard branch → edit → validate → PR flow

## When NOT to Use

- CI failure needs workflow-specific debugging → CI skills
- complex packaging needs a language-specific skill → `packaging-*.md`
- you are still leaking bluefin habits → `not-bluefin.md` first

## Core Process

1. **Load `not-bluefin.md` if needed.**
2. **Branch from `upstream/main`.**
3. **Pick the focused skill for the change.**
4. **Use `just` recipes, not ad-hoc host commands.**
5. **Run the lightest validation that proves the change.**
6. **Commit with `Assisted-by:` and update the relevant skill in the same PR.**

## Always Rules

1. Run `just --list` first.
2. Use `just bst ...`, not bare `bst`.
3. Grep all references before removing a package or file.
4. Add new package elements to the correct stack.
5. Validate before opening the PR.
6. Push to `upstream`, never the fork workflow by accident.

## Never Rules

1. Never solve package/image-content changes in `Containerfile`.
2. Never open a Dakota PR without validation evidence.
3. Never edit junctions casually; treat them as human-review territory.
4. Never add duplicate automation when an existing recipe or workflow already owns it.
5. Never skip the skill update if you discovered a reusable lesson.

## Task Routing

| Task | Load |
|---|---|
| Add package | `add-package.md` |
| Remove package | `remove-package.md` |
| Update source ref/version | `update-refs.md` |
| Debug element build | `debugging.md` |
| BST syntax/reference | `buildstream.md` |
| CI failure | `ci.md` |

## Default Workflow

```bash
# branch
git checkout upstream/main -b fix/short-description

# inspect recipes
just --list

# make the change

# validate with the lightest checks that match the scope
just bst show oci/bluefin.bst
just lint

# commit
git commit -m "fix(bluefin): short description

Closes #NNN

Assisted-by: OpenAI GPT-5 via pi"

# push
git push upstream fix/short-description
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll use bare bst just this once." | That's how environment drift sneaks in. |
| "This is small; I don't need validation." | Small changes still waste CI if the graph is broken. |
| "I learned something, but I'll document it later." | Later means never. The factory loop breaks immediately. |
| "The fork is fine for this push." | Not for Dakota's normal upstream PR flow. |

## Red Flags

- Starting from local `main` instead of `upstream/main`
- Using host-installed bst or random shell commands instead of `just`
- No evidence attached to the PR
- A skill-worthy lesson discovered but not written back

## Verification

- [ ] Branch started from `upstream/main`
- [ ] Correct focused skill was loaded for the task
- [ ] Validation matched the scope of the change
- [ ] Commit uses repo conventions including `Assisted-by:`
- [ ] Skill update is included when a new pattern was learned

## Lessons Learned

### Restarting the publish factory after a pause (2026-06-05)

When publishing has been intentionally paused (e.g., post-repo-refactor), the
factory restart sequence is:

1. Fix any `startup_failure` in `publish.yml` — check for invalid `permissions:` scopes
   (e.g. `artifact-metadata: write` is not a valid GITHUB_TOKEN scope) and
   job-level `permissions:` on reusable workflow call jobs.
2. Dispatch `build.yml --ref main` to populate the remote CAS.
3. Wait ~60–90 minutes for the build to complete.
4. `publish.yml` auto-triggers via `workflow_run`. If not, dispatch manually.
5. After `:testing` lands, dispatch `weekly-testing-promotion.yml` and get
   2 human approvals at https://github.com/projectbluefin/dakota/deployments
   to promote `:testing` → `:latest` + `:stable`.

Full details: `release-promotion.md` and `ci-tooling.md`.
