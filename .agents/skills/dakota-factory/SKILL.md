---
name: dakota-factory
description: Reinforce the Project Bluefin factory model: two-output rule, docs-as-the-model hygiene, Context7 freshness protocol, and skill auditing. Use when finishing sessions, auditing skills, or writing back learned patterns.
metadata:
  context7-sources:
    - /addyosmani/agent-skills
---

# Dakota Factory Model

Every session in Dakota produces exactly **two** outputs: the work and the learning. Output 1 without Output 2 leaves the factory no smarter than before you arrived.

## When to Use

- Ending any implementation, debugging, or triage session that revealed non-obvious behavior or traps
- Creating, auditing, or refactoring skills in `.agents/skills/`
- Updating architectural docs in `docs/` to reflect running truth
- Verifying library or CLI syntax against official documentation via Context7

## When NOT to Use

- Read-only queries that produced no code and surfaced no new patterns
- Pure dependency version updates handled automatically by Renovate

## Core Process

1. **Capture the Learning**: Identify workarounds, traps, or architectural invariants discovered during the task.
2. **Docs Are the Model**:
   - Skill files are evergreen procedures, not historical logs, ledgers, or backlogs.
   - Do not record session dates (e.g. `2026-08-01: we found X`). Extract the timeless rule.
   - Do not maintain running issue tables or resolved checklists in skills. Gaps belong in GitHub issues; resolved items belong in git history.
3. **Audit Against Canonical Skill Spec (`/addyosmani/agent-skills`)**:
   Ensure the affected skill in `.agents/skills/` contains:
   - Frontmatter (`name`, `description` with trigger phrases, `metadata.context7-sources`)
   - `## When to Use`
   - `## When NOT to Use`
   - `## Core Process`
   - `## Invariants` / `## Rules`
   - `## Common Rationalizations`
   - `## Red Flags`
   - `## Verification`
4. **Context7 Documentation Freshness**:
   For any external library, framework, or CLI tool (BuildStream, bootc, systemd, cosign, etc.):
   ```
   DETECT → FETCH → EMBED → CITE
   ```
   - **DETECT**: Identify the external tool.
   - **FETCH**: Resolve library ID via `context7-resolve-library-id` and query via `context7-query-docs`.
   - **EMBED**: Embed verified signatures or patterns into the skill.
   - **CITE**: Record the Context7 library ID in `metadata.context7-sources`.
5. **Atomic Commit**: If the session produced both code and learnings, commit both in the same PR.

## Invariants

- **The Two-Output Invariant**: Never close a session that uncovered a new constraint without writing that constraint back to `.agents/skills/` or `docs/`.
- **Evergreen Truth**: Workflows, elements, the Justfile, and tests are authoritative truth. Prose that disagrees with executable configuration is stale and must be excised.
- **Zero Writing to `ublue-os/*`**: Absolute prohibition. Ask a human to report upstream manually.
- **Commit Trailer**: Use `Assisted-by:`, never `Co-authored-by:`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I will update the documentation in a follow-up PR." | Follow-up PRs are rarely opened. Capture learnings in the same PR as the code change. |
| "Recording the incident date gives good context." | Dated incident logs turn documentation into an unmaintained changelog. Document the timeless failure mode and prevention rule instead. |
| "I know how this CLI tool works from memory." | Model memory drifts and hallucinates flags. Verify current syntax with Context7. |

## Red Flags

- Sections titled `## Lessons Learned` with dated entries (`2026-07-30: ...`)
- Running issue tables with live issue numbers inside skill files
- Skills lacking `## Red Flags` or `## Verification` sections
- Contradictions between `docs/` and executable workflow YAML or `Justfile`

## Verification

- [ ] Every discovered pattern is codified into `.agents/skills/` or `docs/`
- [ ] No dated session logs or resolved checkmarks added to evergreen docs
- [ ] External tool syntax verified via Context7 and cited in metadata
- [ ] Canonical skill structure verified against `/addyosmani/agent-skills`
- [ ] All commits use conventional format with `Assisted-by:` trailer

## References

- [`AGENTS.md`](../../../AGENTS.md)
- [`docs/feedback-loop.md`](../../../docs/feedback-loop.md)
- [`docs/workflow.md`](../../../docs/workflow.md)