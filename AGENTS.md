# bluefin-dakota -- Fork Workflow Notes

This file captures fork-local workflow for `castrojo/dakota`.
Project build and architecture details remain in `README.md`, `Justfile`, and `docs/plans/`.

## Fork Identity

- **Upstream:** `projectbluefin/dakota`
- **Fork:** `castrojo/dakota`
- **Local path:** `~/src/bluefin-dakota`
- **Tracking remote:** `upstream` -> `git@github.com:projectbluefin/dakota.git`

## Skills

cat ~/src/skills/workflow/SKILL.md              # push confirmation, PR safety, session guardrails
cat ~/src/skills/bluefin-build/SKILL.md         # bluefin ecosystem build/validation workflow
cat ~/src/skills/dakota-overview/SKILL.md       # repo purpose, gap analysis, package positioning
cat ~/src/skills/dakota-buildstream/SKILL.md    # .bst authoring reference, variables, source kinds
cat ~/src/skills/dakota-debugging/SKILL.md      # build failure triage for BuildStream
cat ~/src/skills/dakota-ci/SKILL.md             # CI pipeline operations and troubleshooting

## Session Start

```bash
git fetch upstream
git status --short --branch
just --list
```

Use `workflow/SKILL.md` session start protocol from `~/src` before mutating anything.

## Quick Reference

| What | Where |
|---|---|
| Build target | `elements/oci/bluefin.bst` |
| Local build | `just build` |
| End-to-end local test | `just show-me-the-future` |
| Local registry | `just registry-start` / `just publish` |
| CI workflow (primary) | `.github/workflows/build.yml` |
| Build config | `project.conf` |
| Plans | `docs/plans/` |

## Build and Validate

```bash
just build
just lint
```

For heavyweight end-to-end validation:

```bash
just show-me-the-future
```

## Workflow Rules (Fork)

- Never open upstream PRs from automation.
- Push only to `origin` (`castrojo/dakota`), never to upstream.
- Before any push, state branch name, remote, and commit SHA, then wait for explicit confirmation.
- Keep changes scoped; do not include unrelated dirty worktree files.

## Branch and PR Flow

```bash
git switch -c <type>/<short-description>
```

- Branch names must follow conventional format (`feat/`, `fix/`, `chore/`, `docs/`, `refactor/`, `ci/`, `test/`).
- Keep `main` aligned with upstream except fork-local metadata commits.
- Use compare links or `~/src/skills/bluefin-build/scripts/open-pr.sh` for human PR handoff.

## Repository Layout

```
elements/                BuildStream elements (.bst)
  bluefin/               Bluefin-specific packages
  core/                  Core overrides
  oci/                   Image assembly pipeline
patches/                 Junction patches (freedesktop-sdk, gnome-build-meta)
include/                 Shared YAML includes
docs/plans/              Implementation plans and rationale
Justfile                 Local build and test entrypoints
project.conf             BuildStream project settings
```

## Notes

- BuildStream runs inside the pinned bst2 container from `Justfile`.
- Builds are cache-sensitive; warm cache behavior is expected.
- For package additions/removals, prefer the dedicated Dakota package skills from `~/src/skills/INDEX.md`.
