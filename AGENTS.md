# AGENTS.md

Dakota is a [BuildStream 2](https://buildstream.build/) project producing **Bluefin** — a bootc OCI desktop image built from source. No RPMs. No dnf. BST elements only.

Load **[docs/SKILL.md](docs/SKILL.md)** for the full reference skill tree. Only load docs relevant to your task.

## Find something to work on

| Time available | Link |
|---|---|
| 30 min | [XS issues](https://github.com/projectbluefin/dakota/issues?q=is%3Aopen+label%3Aqueue%2Fagent-ready+label%3Asize%2Fxs+no%3Aassignee) |
| Half day | [S issues](https://github.com/projectbluefin/dakota/issues?q=is%3Aopen+label%3Aqueue%2Fagent-ready+label%3Asize%2Fs+no%3Aassignee) |
| Full day | [M issues](https://github.com/projectbluefin/dakota/issues?q=is%3Aopen+label%3Aqueue%2Fagent-ready+label%3Asize%2Fm+no%3Aassignee) |
| All | [Everything ready](https://github.com/projectbluefin/dakota/issues?q=is%3Aopen+label%3Aqueue%2Fagent-ready+no%3Aassignee+sort%3Acreated-asc) |

Comment `/claim` on an issue to take it. Actionadon assigns it and removes it from the pool. No PR activity in 7 days returns it automatically.

---

## Mandatory gates

Non-compliance = automatic rejection.

**Read-First:** Read `README.md`, `AGENTS.md`, `.github/copilot-instructions.md`, and `docs/SKILL.md` before modifying anything. Do not assume project structure or patterns.

**Rate limit:** Max 4 open PRs at a time. If a PR is closed for quality, document the root cause on the closed PR before resubmitting.

**Operator accountability:** The human deploying the agent is responsible for all decisions. PR template checkbox: `[ ] I am using an agent and I take responsibility for this PR`

**Verification:** Every PR must confirm `just lint` passed and the image booted. Use `just boot-test` for automated pass/fail. No WIP PRs.

**Justfile integrity:** All maintenance tasks must be `just` recipes. No loose shell commands. If a task isn't covered by an existing recipe, add one alongside your change.

**Human maintainability:** Every agent action must be replicable by a human via the Justfile. No AI-optimized black boxes. Do not rename existing recipes without explicit human approval.
