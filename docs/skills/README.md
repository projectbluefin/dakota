---
name: skills-index
description: Routing table for Dakota's in-repo skills. Load this when you need to find the right skill fast instead of reading everything. Use when starting work, switching problem domains, or deciding which focused skill to load next.
metadata:
  context7-sources:
    - /addyosmani/agent-skills
---

# docs/skills — In-Repo Skill Index

## Overview

This directory is Dakota's **working memory**.
Read the smallest skill that answers the job. Do not load every file just because it exists.

The factory model depends on this discipline:
- **Work** lands as code or docs
- **Learning** lands as a focused skill update in the same PR

## When to Use

Use this file when:
- starting a Dakota task
- switching from one problem class to another
- deciding which skill to load next
- cleaning up or splitting an overgrown skill

## When NOT to Use

- You already know the exact focused skill you need
- You are looking for raw project docs rather than agent workflow guidance

## Core Process

1. **Load `not-bluefin.md` first** if there is any chance you are drifting into dnf/RPM/Containerfile habits.
2. **Pick the narrowest skill** that matches the task.
3. **Read the actual file or workflow** before editing code.
4. **Verify external tool behavior with Context7** before changing syntax, flags, or API usage.
5. **Write back learnings** to the narrowest skill file, not the nearest giant dumping ground.

## Fast Paths

### Build / packaging
- Add package → `add-package.md`
- Remove package → `remove-package.md`
- Update version or ref → `update-refs.md`
- Need BST syntax or element kinds → `buildstream.md`
- Need a language-specific packaging pattern → `packaging-*.md`

### CI / release
- Need to know which workflow owns the stage → `workflow-map.md`
- Reusable workflow / token / cache weirdness → `ci-tooling.md`
- boot-check, smoke, testsuite, QEMU → `e2e-ci.md`
- promotion PRs and stable release flow → `release-promotion.md`
- stale queue branches / conflicting bot PRs → `merge-queue.md`
- historical deep cuts → `ci-reference.md`

### Factory workflow
- Issue lifecycle, data donation, slash commands → `actionadon.md`
- Routine zero-context maintenance → `quickstart.md`
- Review flow → `pr-review.md`
- Repo/product context → `overview.md`

## Routing Table

| Task | Load |
|---|---|
| **Reset the Dakota mental model first** | **`not-bluefin.md`** |
| Routine maintenance with low context | `quickstart.md` |
| Add a package | `add-package.md` |
| Remove a package | `remove-package.md` |
| Update a package version or source ref | `update-refs.md` |
| BST YAML, kinds, variables, or structure | `buildstream.md` |
| Debug an element build failure | `debugging.md` |
| OCI image layer assembly | `oci-layers.md` |
| Junction overrides | `bst-overrides.md` |
| Patch junction elements | `patch-junctions.md` |
| Package a pre-built binary | `packaging-binaries.md` |
| Package a Go project | `packaging-go.md` |
| Package a Rust project | `packaging-rust.md` |
| Package a Zig project | `packaging-zig.md` |
| Package a GNOME Shell extension | `packaging-gnome-extensions.md` |
| Local OTA testing | `local-ota.md` |
| Figure out which CI workflow owns the problem | `workflow-map.md` |
| Reusable workflow / token / cache / startup failures | `ci-tooling.md` |
| boot-check, smoke, testsuite wiring | `e2e-ci.md` |
| Promotion PRs and stable release flow | `release-promotion.md` |
| Historical CI edge cases | `ci-reference.md` |
| Merge queue cleanup | `merge-queue.md` |
| Issue lifecycle / Actionadon / data donation | `actionadon.md` |
| Installer work | `installer.md` |
| VM stack context | `vm-stack.md` |
| Repo and product overview | `overview.md` |
| PR review workflow | `pr-review.md` |
| ujust recipes in `files/just-overrides/` | `.github/skills/ujust-recipes.md` |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just read the biggest skill so I don't miss anything." | That's how agents waste context and still miss the relevant part. |
| "This new lesson can go into the nearest large file." | Large files rot. Put the lesson in the narrowest skill or split a new one. |
| "I know the tool well enough; I don't need docs." | The repo explicitly optimizes for source-driven work. Use Context7. |
| "The router can hold one more giant subsection." | No. Route, then split. |

## Red Flags

- A skill grows into a catch-all for multiple failure classes
- New lessons land in a giant history dump instead of a focused skill
- Agents load 500+ lines before they know which subsystem failed
- The route table points to one file for three unrelated jobs

## Verification

- [ ] The route table points to the narrowest useful skill
- [ ] CI topics are split by workflow map, tooling, boot/e2e, and promotion
- [ ] New skill growth reinforces the factory model instead of creating a second archive
- [ ] External tool behavior is verified via Context7 before skills are updated

## Related

- `../SKILL.md` — top-level skill router
- `../../AGENTS.md` — repo rules and factory policy
- `../../files/hive/agent-policies/` — Hive role policy files
