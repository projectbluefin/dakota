# AGENTS.md

Dakota is a [BuildStream 2](https://buildstream.build/) project producing **Dakota** — Project Bluefin's bootc OCI desktop image built from source. No RPMs. No dnf. No Containerfile package overlays. BST elements only. Historical `bluefin/` paths in this repo are Dakota build paths, not permission to use bluefin's dnf/RPM workflow. Load [`docs/skills/not-bluefin.md`](docs/skills/not-bluefin.md) FIRST if you have any bluefin context.

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
dakota  (next→:next/:btw, rolling nightly, no stable promotion)
                                 │
                                 ▼
                                iso (installation media)
```

Each image repo pulls `ghcr.io/projectbluefin/common:latest` as a base layer.
testsuite gates `:testing` promotion nightly and `:latest`/`:stable` promotion weekly.

**Dakota image streams:**
- `:testing` / `:latest` / `:stable` — `main` branch, GNOME 50 stable, e2e-gated weekly promotion
- `:next` / `:btw` — `next` branch, GNOME 51 master, fully automated rolling nightly, **no promotion to stable ever**

**`elements/bluefin/common.bst` strips bluefin-only content from common.** Any file added to `common/system_files/shared/` that does not apply to a fresh dakota install must be explicitly `rm -f`'d in the `install-commands` block of that element. Current stripped files: `rechunker-group-fix` script, service, and preset (chunka migration aid — not needed on fresh dakota).

### 🚫 Absolute prohibition — ublue-os org

**NEVER create issues, pull requests, comments, forks, webhook calls, API writes, automated reports, or any other programmatic action targeting any `ublue-os/*` repository.**

This applies in every situation, without exception:
- Issues, comments, PRs, forks → **BANNED**
- Automated reports (bonedigger output, CI notifications, diagnostic uploads) → **BANNED**
- `workflow_dispatch` or `repository_dispatch` calls to `ublue-os/*` → **BANNED**
- Any `gh` CLI command that writes to `ublue-os/*` → **BANNED**

If a task seems to require touching an upstream `ublue-os` repo → **stop and tell the human to report it manually.** Violating this risks getting the projectbluefin organization banned from GitHub.

---

## The Self-Improvement Loop

> **This is the core operating model. Read it.**

Every agent session produces two outputs:
1. **The work** — the PR, fix, or improvement.
2. **The learning** — what you discovered that a future agent should know.

Output 1 without Output 2 leaves the system no smarter. **The loop only compounds if agents write back.**

```
Agent works on task
  └─ discovers pattern / workaround / convention
       └─ writes it to the relevant skill file in docs/skills/
            └─ commits in the same PR
                 └─ next agent starts smarter
                      └─ loop
```

### Skill-improvement mandate

**Before marking your work complete / before requesting final review:**

- [ ] Did I discover any workaround, non-obvious pattern, or convention?
- [ ] Is there a skill file for the area I worked in?
- [ ] If yes — did I update it?
- [ ] If no — did I create one?
- [ ] Is the skill file committed in this same PR?

### What counts as a learning worth writing back

**Write it:**
- A workaround for an upstream bug (include component + issue link)
- A non-obvious pattern required for correctness
- A convention that isn't obvious from the code
- Something you had to discover by trial and error

**Don't write it:**
- One-off task notes ("use commit message X for this PR")
- Obvious things any developer would know
- Ephemeral state ("currently broken, fix pending")

### Where learnings live

| You are working in... | Write to |
|---|---|
| `projectbluefin/dakota` | That repo's `docs/skills/` — create if absent |
| Cross-cutting (affects multiple repos) | Local first, then open propagation issue in `projectbluefin/actions` |
| `ublue-os/*` repos | **NEVER write to these repos** — no issues, PRs, comments, forks, webhooks, or automated reports. Tell the human to report manually. |

---

## Data donation

Dakota bugs are data donations. `ujust report` captures full system state to a user-owned gist before the issue opens. That report is the ground truth.

The pipeline widget in every issue body reflects that donation: `report: attached` means full telemetry is available. `confirms: N` means N people hit it on real hardware. `verified: N/3` drives closure.

**Agent rule:** If `report: attached`, read the gist before doing anything. If `confirms: N` is > 2, treat it as higher priority. Never close an issue at `done` with `verified: 0/3` without maintainer sign-off.

Full details: `docs/feedback-loop.md` and `docs/skills/actionadon.md`.

## Mandatory gates

Non-compliance = automatic rejection.

**Read-First:** Read `README.md`, `AGENTS.md`, `.github/copilot-instructions.md`, and `docs/SKILL.md` before modifying anything. Do not assume project structure or patterns.

**Operator accountability:** The human deploying the agent is responsible for all decisions. PR template checkbox: `[ ] I am using an agent and I take responsibility for this PR`

**Verification:** Every PR must confirm `just lint` passed and the image booted. Use `just boot-test` for automated pass/fail. No WIP PRs.

**Pre-commit guard:** `no-floating-action-tags` blocks third-party `@main`/`@v*` floating action tags at commit time. `projectbluefin/` refs (`@v1`, `@main`) are intentional managed tags and are exempted.

**Justfile integrity:** All maintenance tasks must be `just` recipes. No loose shell commands. If a task isn't covered by an existing recipe, add one alongside your change.

**Human maintainability:** Every agent action must be replicable by a human via the Justfile. No AI-optimized black boxes. Do not rename existing recipes without explicit human approval.

## Human Decision Points — Stop and Ask

Agents implement autonomously **except** at these gates. Stop and request human input:

| Gate | When |
|---|---|
| **Design Gate** | Architecture changes, new subsystem design, behavioral changes visible to users |
| **Security Gate** | Auth, signing, supply chain, secrets handling, COPR/third-party sources |
| **Breakage Gate** | Cross-repo breaking changes — removing/renaming inputs, changing defaults that affect consuming repos |
| **Merge Gate** | Final PR approval and merge — always human |

When in doubt, open a draft PR with your implementation and ask explicitly.

## Verification — Implement and Verify; Humans Approve and Merge

Do not request review without evidence. Before opening a PR for review:

- Link to a CI run, workflow run, or test output that exercises your change
- If no automated test exists, describe how you manually verified the change
- Skill file update must be committed in the same PR (not a follow-up)

### Who does what

| Audience | Entry point | Labels to look for |
|---|---|---|
| **Architects / designers** | Features and epics needing design input | `status/discussing` + `type/feature` or `kind/epic` |
| **Engineers / agents** | Issues ready to build — criteria defined, no open questions | `status/queued` + no assignee |

`status/discussing` is for shaping **what** to build and **why**. It is not a bug triage queue — keep bug reports out of it. Engineers should not be blocked on `status/discussing` issues; they should work from `status/queued`.

### Triage labels

| Label | What it means |
|---|---|
| `status/discussing` | Feature or design question open for architect/designer input. Not ready for implementation. |
| `status/approved` | Approved for queue preparation — needs acceptance criteria before queue. |
| `status/claimed` | Actively being worked by a human or agent. |
| `agent/blocked` | Blocked and needs human input before work can continue. |
| `hold` | Do not touch; intentionally held by humans. |
| `do-not-merge` | Do not merge or automate this item. |
| `status/queued` | Issue is scoped with clear acceptance criteria. Ready for an agent or contributor to pick up and open a PR. |
| `kind/epic` | Groups related issues into a single tracked effort. Never prefix the title with "Epic:" — use this label instead. |
| `type/feature` | New capability or user-facing improvement. Use for `status/discussing` issues that need design input. |
| `lgtm` | PR approved by a maintainer. |
| `help wanted` | Good for any contributor, including agents. |
| `kind:bug` | Something is broken and needs fixing. |
| `kind:improvement` | Enhancement or cleanup — no spec required for small items. |
| `kind:tech-debt` | Cleanup with no user-visible change. |
| `kind:github-action` | CI or automation changes. |
| `flow/agent-donation` | A donated-agent request to investigate a repo, issue, or PR and return a report instead of code. |
| `flow/project-report` | Scanner flow for a linked repository, org, roadmap, or docs report. |
| `flow/issue-review` | Scanner flow for a linked issue review. |
| `flow/pr-review` | Reviewer flow for a linked PR review. |
| `lab:pass` | Maintainer lab validation passed; enables label-gated auto-merge for maintainer-owned PR branches. After `lab:pass`, one maintainer ack/approval is sufficient for merge-queue entry. |
| `needs-human/agent-oops` | An agent made a mistake here — wrong assumption, bad output, filed a spurious issue, broke something. This label builds a learning corpus. |

**Skill contribution:** If you discover a pattern, fix a recurring mistake, or learn something that would help future agents, you **must** update the relevant skill file in `docs/skills/` in the same PR as your change. If no relevant skill file exists, create one and add it to the routing table in `docs/skills/README.md`. Skills are living documents — every agent improves them.

**Agents MUST NOT push directly to `main`.** All changes via PR from a feature branch. Branch protection enforces this.

**Production promotion** (`weekly-testing-promotion.yml`) requires 2 distinct human approvals in the GitHub `production` Environment. No agent may trigger, approve, or bypass this gate. Admin bypasses are permanently logged in Environment deployment history.

**Promotion pipeline — cosign verify pattern:** When adding cosign verification to a promotion workflow, anchor the `--certificate-identity-regexp` with `^...$` and restrict it to the specific publishing workflow file and allowed ref patterns (e.g. `^https://github.com/<repo>/.github/workflows/publish\.yml@refs/heads/(main|gh-readonly-queue/main/.+)$`). An unanchored wildcard accepts signatures from any workflow in the repo.

**cosign install on GHA runners:** Never write directly to `/usr/local/bin` without `sudo`. Use `curl -fsSL ... -o "$RUNNER_TEMP/cosign"` then `sudo install -m 0755 "$RUNNER_TEMP/cosign" /usr/local/bin/cosign`. The runner user cannot write to `/usr/local/bin` on GitHub-hosted runners.

**TOCTOU guard in promotion workflows:** The `lock-sha` step must lock the *tested* source SHA (from the `verify` step output), not the live `main` HEAD. Compare the live HEAD to the tested SHA and fail early if they differ. Locking the live HEAD after testing is a race — `main` may have advanced between the e2e run and the lock step.

**`.github/workflows/`, `Justfile`, `build_files/`, and `elements/` are CODEOWNERS-protected** — PRs touching these paths require maintainer review.

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

## Development Standards

### Commit format (required)

[Conventional Commits](https://www.conventionalcommits.org/): `<type>(<scope>): <description>`

Common types: `feat` `fix` `docs` `ci` `refactor` `chore` `build`

### AI attribution (required)

```
feat(bluefin): add container build optimization

Closes #NNN

Assisted-by: Claude Sonnet 4.6 via GitHub Copilot
```

Per `docs/pr-checklist.md`: always `Assisted-by:` — **never `Co-authored-by:`** (this is a repo-local rule that differs from the org-wide template).

### SHA pinning (actions only)

All `uses:` references to external actions must be pinned to a full commit SHA with a version comment. Never use floating tags. `projectbluefin/` refs (`@v1`, `@main`) are intentional managed tags and are exempted.
