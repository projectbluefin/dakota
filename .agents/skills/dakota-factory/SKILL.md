---
name: dakota-factory
description: "Maintain task-relevant Dakota guidance: documentation accuracy, official-source verification, and skill auditing. Use when auditing skills or correcting durable guidance revealed by a task."
---

# Dakota Factory Model

Keep documentation aligned with executable configuration. Correct durable guidance relevant to the task, without requiring a documentation change for every session.

## When to Use

- Ending any implementation, debugging, or triage session that revealed non-obvious behavior or traps
- Creating, auditing, or refactoring skills in `.agents/skills/`
- Updating architectural docs in `docs/` to reflect running truth
- Verifying library or CLI syntax against current official documentation

## When NOT to Use

- Read-only queries without authorization to change documentation
- Pure dependency version updates handled automatically by Renovate

## Core Process

1. **Check Relevance and Authority**: Identify durable errors or missing constraints relevant to the task. Correct existing guidance when edits are authorized; otherwise report the finding without writing files.
2. **Docs Are the Model**:
   - Skill files are evergreen procedures, not historical logs, ledgers, or backlogs.
   - Do not record session dates (e.g. `2026-08-01: we found X`). Extract the timeless rule.
   - Do not maintain running issue tables or resolved checklists in skills. Gaps belong in GitHub issues; resolved items belong in git history.
3. **Audit Skill Usability**:
   Ensure the affected skill in `.agents/skills/` contains:
   - Valid YAML frontmatter with `name` and a descriptive `description`; optional metadata should identify real sources, not unavailable tool requirements
   - `## When to Use`
   - `## When NOT to Use`
   - `## Core Process`
   - `## Invariants` / `## Rules`
   - `## Common Rationalizations`
   - `## Red Flags`
   - `## Verification`
4. **Verify Official Documentation**:
   - Identify the external tool and the version used by Dakota.
   - Read its current official documentation directly, or use Context7 when available.
   - Verify the specific syntax or behavior against the pinned source when needed.
   - Cite the official URL in relevant guidance or optional `metadata.verified-sources`.
5. **Keep Changes Scoped**: Include relevant documentation corrections with the code diff for review. Do not add unrelated writebacks, create a commit, or publish a PR without authorization.

## Invariants

- **Task Boundary**: Documentation changes must be useful, relevant, and authorized. A read-only task can end with findings alone.
- **Evergreen Truth**: Workflows, elements, the Justfile, and tests are authoritative truth. Prose that disagrees with executable configuration is stale and must be excised.
- **Zero Writing to `ublue-os/*`**: Absolute prohibition. Ask a human to report upstream manually.
- **Commit Trailer**: Use `Assisted-by:`, never `Co-authored-by:`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Every task needs a documentation diff." | Update guidance when the task changes or corrects it; do not manufacture unrelated work. |
| "Recording the incident date gives good context." | Dated incident logs turn documentation into an unmaintained changelog. Document the timeless failure mode and prevention rule instead. |
| "I know how this CLI tool works from memory." | Verify current syntax in official documentation. Context7 is an optional retrieval tool, not a prerequisite. |

## Red Flags

- Sections titled `## Lessons Learned` with dated entries (`2026-07-30: ...`)
- Running issue tables with live issue numbers inside skill files
- Skills lacking `## Red Flags` or `## Verification` sections
- Contradictions between `docs/` and executable workflow YAML or `Justfile`

## Verification

- [ ] Documentation changes are task-relevant and authorized
- [ ] No dated session logs or resolved checkmarks added to evergreen docs
- [ ] External tool syntax is verified against official sources and cited where relevant
- [ ] Skill frontmatter parses, referenced paths exist, and commands match available tooling
- [ ] All commits use conventional format with `Assisted-by:` trailer

## References

- [`AGENTS.md`](../../../AGENTS.md)
- [`docs/feedback-loop.md`](../../../docs/feedback-loop.md)
- [`docs/workflow.md`](../../../docs/workflow.md)