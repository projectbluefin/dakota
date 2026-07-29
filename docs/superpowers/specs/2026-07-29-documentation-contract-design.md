# Documentation Contract Design

## Goal

Integrate the recent documentation refactor into one coherent repository
improvement that reduces duplicated agent guidance, preserves useful project
references, and makes documentation drift detectable.

## Scope

- Keep `README.md`, `AGENTS.md`, and `CONTRIBUTING.md` as thin canonical entry
  points.
- Make `docs/skills/index.md` the only skill router.
- Move every skill from `docs/skills/<topic>.md` to
  `docs/skills/<topic>/SKILL.md`.
- Update all tracked links and remove legacy routers and flat skill files.
- Keep concise canonical references for architecture, build, QA, feedback-loop,
  and release behavior.
- Move procedural details into the narrowest skill module and link to the
  executable source of truth.
- Add documentation validation, focused tests, a `just docs-check` recipe, and
  advisory documentation-hygiene CI.

## Non-goals

- No compatibility wrappers for old flat skill paths.
- No issue-template redesign.
- No product-code changes.
- No changes to build, publish, release, or other CI behavior.
- No unrelated cleanup of existing worktree changes.

## Design

The documentation tree has three layers:

1. Product and contributor orientation in the root entry documents.
2. Stable conceptual references under `docs/`.
3. Task-specific, lazy-loaded agent skills under `docs/skills/*/SKILL.md`.

The entry documents route readers to the narrowest relevant document rather
than duplicating instructions. Reference pages explain durable boundaries and
link to `Justfile`, workflows, scripts, and BuildStream elements for current
implementation details.

The skill router is maintained as Markdown and points directly to each module.
Each module has a bounded size and a single responsibility. CI guidance is
split by failure domain instead of retaining large catch-all manuals.

## Validation

`scripts/check_docs.py` will validate:

- relative Markdown links;
- one-H1 and sequential heading structure;
- canonical skill directory layout and size budgets;
- absence of legacy router paths and stale planning/history artifacts;
- absence of client-specific instruction text.

`scripts/test_check_docs.py` covers these checks. `just docs-check` is the
human-reproducible entry point, and `.github/workflows/docs-hygiene.yml` runs
it without affecting image or release pipelines.

## Success criteria

- Every tracked documentation link resolves.
- No flat skill files or duplicate routers remain.
- The documentation checker and focused tests pass.
- The final tracked Markdown footprint is reported with file, line, and byte
  comparisons against the pre-refactor baseline.
- Existing unrelated worktree changes remain untouched.
