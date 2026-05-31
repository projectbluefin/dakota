# AGENTS.md

Dakota is a [BuildStream 2](https://buildstream.build/) project producing **Bluefin** — a bootc OCI desktop image built from source. No RPMs. No dnf. BST elements only.

Load **[docs/SKILL.md](docs/SKILL.md)** for the full reference skill tree. Only load docs relevant to your task.

## Org pipeline — projectbluefin

### Repo map

```
common ──────────────────────────┐
(shared OCI layer)               │
                                 ▼
bluefin  (main→stable)       ←── images ──→ testsuite (e2e gate)
bluefin-lts (main→lts)       ←── images ──→ testsuite (e2e gate)
dakota  (main→testing→latest/stable) ←── images ──→ testsuite (e2e gate)
                                 │
                                 ▼
                                iso (installation media)
```

Each image repo pulls `ghcr.io/projectbluefin/common:latest` as a base layer.
testsuite gates `:testing` promotion nightly and `:latest`/`:stable` promotion weekly.

---## Data donation

Dakota bugs are data donations. `ujust report` captures full system state to a user-owned gist before the issue opens. That report is the ground truth.

The pipeline widget in every issue body reflects that donation: `report: attached` means full telemetry is available. `confirms: N` means N people hit it on real hardware. `verified: N/3` drives closure.

**Agent rule:** If `report: attached`, read the gist before doing anything. If `confirms: N` is > 2, treat it as higher priority. Never close an issue at `done` with `verified: 0/3` without maintainer sign-off.

Full details: `docs/feedback-loop.md` and `docs/skills/actionadon.md`.

## Mandatory gates

Non-compliance = automatic rejection.

**Read-First:** Read `README.md`, `AGENTS.md`, `.github/copilot-instructions.md`, and `docs/SKILL.md` before modifying anything. Do not assume project structure or patterns.

**Rate limit:** Max 4 open PRs at a time. If a PR is closed for quality, document the root cause on the closed PR before resubmitting.

**Operator accountability:** The human deploying the agent is responsible for all decisions. PR template checkbox: `[ ] I am using an agent and I take responsibility for this PR`

**Verification:** Every PR must confirm `just lint` passed and the image booted. Use `just boot-test` for automated pass/fail. No WIP PRs.

**Justfile integrity:** All maintenance tasks must be `just` recipes. No loose shell commands. If a task isn't covered by an existing recipe, add one alongside your change.

**Human maintainability:** Every agent action must be replicable by a human via the Justfile. No AI-optimized black boxes. Do not rename existing recipes without explicit human approval.

## PR Comment Policy

**One comment per PR event, max.** Combine all findings into a single comment. Never post a follow-up comment for a new observation — edit the existing one instead.

**Never duplicate GitHub UI state.** Do not post approval counts, merge queue status, or CI pass/fail summaries — GitHub already surfaces these natively in the PR timeline.

**Test reports: minimal.** Report what ran, pass/fail, and blockers only. No diff summaries. No tables unless comparing ≥3 divergent approaches that require a human decision.

**@ mentions in context only.** Only ping someone if asking them to do something specific. Always inside the combined comment — never as a standalone comment.

**When in doubt, don't post.** If the only thing to report is "tests pass", post nothing.

## PR Review

When asked to review a pull request, load the branch workflow before giving feedback:

1. Read [`docs/workflow.md`](docs/workflow.md) — issue lifecycle, labels, and branch flow
2. Read [`docs/pr-checklist.md`](docs/pr-checklist.md) — per-category checklist (all PRs, junction bumps, patches, OCI, elements)

**Review priorities (in order):**

1. **Branch hygiene** — PR must branch from `upstream/main`, not a fork's local `main`. Check `git diff upstream/main...HEAD --stat` is minimal.
2. **Checklist compliance** — verify the relevant checklist items from `pr-checklist.md` for the type of change.
3. **CI gate status** — `validate` and `e2e` are required status checks. If CI hasn't run, note it.
4. **Scope discipline** — one logical change per PR. Junction bumps must not include patch modifications in the same commit.
5. **Correctness** — element syntax, layer kind (`compose` not `stack`), cargo sources generated not hand-written, etc.

**Recommend the workflow.** If a contributor's PR doesn't follow the branch flow (e.g., branched from fork `main`, missing `Closes #NNN`, no checklist in PR body), guide them toward the correct pattern documented in `docs/workflow.md` rather than just rejecting.
