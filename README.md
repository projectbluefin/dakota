# Bluefin Dakota
*Dakotaraptor steini*

[Bluefin](https://projectbluefin.io) built on [GNOME OS](https://os.gnome.org/), assembled entirely from source.

<a href="https://docs.projectbluefin.io/changelogs">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://docs.projectbluefin.io/img/cards/dakota-dark.png">
    <img src="https://docs.projectbluefin.io/img/cards/dakota-light.png" alt="Bluefin Dakota" width="800">
  </picture>
</a>

**Alpha** — [filing issues](https://github.com/projectbluefin/dakota/issues) is the whole point.

## Built-in feedback loop

Dakota doesn't eat tickets, it treats them as evidence.

Every user running Dakota is part of a structured loop that flows directly back into upstream GNOME, freedesktop, and the kernel. When something breaks on your hardware, you have three commands:

| Command | What it does |
|---|---|
| `ujust report` | Captures your system state and opens a pre-filled issue. One command instead of a wall of "please attach logs." |
| `ujust confirm <issue>` | Tells the team your hardware hits the same bug. Adds a hardware fingerprint to the issue — no duplicate filing. |
| `ujust verify <issue>` | After a fix ships in a nightly, confirms it works on your machine. Closes the loop with evidence. |

No telemetry. No phone-home. Every report is reviewed by you before it leaves your machine, lives in a gist you own, and can be deleted anytime.

When three users independently run `ujust verify` on a fix, that issue closes with real confidence — not just "we think this is fixed."

### The hardware layer

Each Dakota installation is designed to run as a hardware diagnostic lab for itself. When will you find your first?

[Read the full feedback loop design](docs/feedback-loop.md)

## The research behind it

Dakota is human driven with contribution workflows for agents, so if you have tokens to donate, ask it to review issues or PRs, it's useful! The humans make the final decisions. We coordinate this project via a tool called [Hive](https://github.com/kubestellar/hive) from Kubestellar, a CNCF Sandbox project.

Dakota's feedback loop model is grounded in Andy Anderson's work on autonomous AI-assisted software development. The core finding: the intelligence of a system like this lives not in any single model, but in the infrastructure of instructions, tests, metrics, and feedback loops surrounding it.

- [The AI Codebase Maturity Model](https://arxiv.org/abs/2604.09388) — the arxiv paper
- [When AI agents become contributors](https://www.cncf.io/blog/2026/05/14/when-ai-agents-become-contributors-how-kubestellar-reached-81-pr-acceptance/) — CNCF blog
- [Beyond prompting: How KubeStellar reached 81% PR acceptance](https://thenewstack.io/ai-codebase-maturity-model/) — The New Stack
- [KubeStellar Hive](https://github.com/kubestellar/hive) — the reference implementation Dakota draws from

## Help shape what gets built

**Architects and designers** — these features and epics need your input before any code is written. Design decisions, tradeoffs, and priorities:

### [Open features and epics for discussion &rarr;](https://github.com/projectbluefin/dakota/issues?q=is%3Aopen+label%3Astatus%2Fdiscussing+label%3Atype%2Ffeature%2Ckind%2Fepic)

Leave a comment, challenge the design, propose alternatives. When a discussion reaches consensus a maintainer marks it `status/approved` and it enters the build queue.

**Engineers** — these issues have clear acceptance criteria and no open design questions. Pick one up and build it:

### [Agent-ready build queue &rarr;](https://github.com/projectbluefin/dakota/issues?q=is%3Aopen+label%3Aqueue%2Fagent-ready+no%3Aassignee)

Comment `/claim` to take an issue. See [AGENTS.md](AGENTS.md) for the full contributor workflow.

## Help shape what gets built

These issues need human judgment before any code is written — design review, domain knowledge, or hardware context the team doesn't have yet:

### [Issues open for discussion &rarr;](https://github.com/projectbluefin/dakota/issues?q=is%3Aopen+label%3Astatus%2Fdiscussing)

Leave a comment, push back on the design, or share how your hardware is affected. When a discussion reaches consensus, a maintainer marks it `status/approved` and it enters the contributor queue.

Ready to build something? See the [agent-ready queue](https://github.com/projectbluefin/dakota/issues?q=is%3Aopen+label%3Aqueue%2Fagent-ready+no%3Aassignee) for issues with clear acceptance criteria and no open questions.

## Image streams

| Tag | Stream | What it is |
|---|---|---|
| `:latest` | Stable | GNOME 50 — production. Weekly promotion from `:testing`. |
| `:testing` | Dev | GNOME 50 — daily builds from `main`. Gated by e2e before promotion. |
| `:next` | Rolling | **GNOME master — the bleeding edge.** Tracks gnome-build-meta `master` daily. Auto-updates, zero maintenance. |
| `:btw` | Rolling | Alias for `:next`. |

`:next` / `:btw` is the arch competitor stream — latest GNOME the moment it lands upstream, built from source with memory-safe defaults (sudo-rs, uutils-coreutils). If you want to run GNOME before everyone else and help find regressions before they reach stable, this is your image.

```bash
# Switch to the rolling stream
sudo bootc switch ghcr.io/projectbluefin/dakota:next
# or
sudo bootc switch ghcr.io/projectbluefin/dakota:btw
```

## ISO Download

[dakota-live-latest.iso](https://projectbluefin.dev/dakota-live-latest.iso) · [Checksum](https://projectbluefin.dev/dakota-live-latest.iso-CHECKSUM)


## Known gaps

- Installation path is still being worked on
- Upgrades and rollbacks need more hardening

See the [open issues](https://github.com/projectbluefin/dakota/issues) for where things stand.

## Contributing or building from source

See [AGENTS.md](AGENTS.md) for the full contributor workflow, build instructions, and PR checklist.

![Dakorator](https://github.com/user-attachments/assets/ee92291d-a617-496e-abb6-9045a4c665ce)
