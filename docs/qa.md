# Dakota QA and evidence

Dakota treats verification as evidence, not ceremony.

This page defines the proof model. For current command behavior, workflow triggers, and implementation details, read the owning recipe or workflow.

## Principle

Run the **smallest check that proves the change** without skipping checks that protect the affected boundary.

- Docs routing changes need documentation validation.
- Build graph changes need graph validation.
- Runtime/image changes need image and boot evidence.
- Publish/release changes need targeted workflow/source review plus the narrowest validation that proves the contract still holds.

## Stable local entry points

Use `just --list` for the full command surface. These are the core QA entry points:

| Command | What it proves |
|---|---|
| `just docs-check` | tracked Markdown structure, links, and docs-contract rules |
| `just validate` | BuildStream graph + workflow validation invariants |
| `just patch-drift-check` | local patch queue still matches the pinned imported source |
| `just build [variant]` | a target OCI element builds successfully |
| `just export [variant]` | built OCI artifact can be exported locally |
| `just lint` | exported image satisfies `bootc container lint` |
| `just boot-test` | automated local boot smoke passes |

The authoritative implementation for these commands is the [`Justfile`](../Justfile).

## Evidence by change class

| Change class | Typical minimum proof | Primary source of truth |
|---|---|---|
| Docs and navigation | `just docs-check` | [`scripts/check_docs.py`](../scripts/check_docs.py) |
| BuildStream graph / elements | `just validate` | [`Justfile`](../Justfile), [`.github/workflows/validate.yml`](../.github/workflows/validate.yml) |
| Junction / patch maintenance | `just patch-drift-check` + `just validate` | [`Justfile`](../Justfile) |
| Runtime / image behavior | the narrowest applicable combination of `just build`, `just export`, `just lint`, `just boot-test` | [`Justfile`](../Justfile) |
| Publish / release / rollback contract | targeted workflow review plus any matching local recipe proof | [`docs/release.md`](release.md), workflow files |

## CI evidence

The GitHub workflows are the canonical automated evidence sources:

- [`.github/workflows/validate.yml`](../.github/workflows/validate.yml) — graph / workflow validation on PR and merge-queue paths
- [`.github/workflows/e2e.yml`](../.github/workflows/e2e.yml) — delegated desktop e2e entry point
- [`.github/workflows/build.yml`](../.github/workflows/build.yml) — BuildStream OCI build pipeline
- [`.github/workflows/publish.yml`](../.github/workflows/publish.yml) — publish, boot-check, signing, SBOM attachment

Do not duplicate the workflow logic in prose. Read the workflow you are changing.

## Done means verified

Do not treat "I pushed it" as completion.

For Dakota work, done means:
- the relevant local checks were run or an equivalent reason is documented
- the owning CI checks are green, skipped for a valid reason, or intentionally out of scope
- the evidence is attached to the PR or handoff report

## Feedback-loop evidence

Local QA is only one layer. User evidence and hardware confirmations are part of the product design.

Use [`docs/feedback-loop.md`](feedback-loop.md) when the task is driven by a bug report, `ujust report`, `ujust confirm`, or `ujust verify` evidence.
