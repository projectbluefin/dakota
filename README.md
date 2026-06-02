# Bluefin Dakota
*Dakotaraptor steini*

[![Build Bluefin dakota](https://github.com/projectbluefin/dakota/actions/workflows/build.yml/badge.svg)](https://github.com/projectbluefin/dakota/actions/workflows/build.yml) [![Scorecard supply-chain security](https://github.com/projectbluefin/dakota/actions/workflows/scorecard.yml/badge.svg)](https://github.com/projectbluefin/dakota/actions/workflows/scorecard.yml) [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/projectbluefin/dakota)

[Bluefin](https://projectbluefin.io) built on [GNOME OS](https://os.gnome.org/), assembled entirely from source. **Alpha** — [filing issues](https://github.com/projectbluefin/dakota/issues) is the whole point.

![Dakorator](https://github.com/user-attachments/assets/ee92291d-a617-496e-abb6-9045a4c665ce)

## Latest Release

<a href="https://docs.projectbluefin.io/changelogs/">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://docs.projectbluefin.io/img/cards/dakota-dark.png">
    <img src="https://docs.projectbluefin.io/img/cards/dakota-light.png" alt="Bluefin Dakota latest release" width="800">
  </picture>
</a>

## Images

Full catalog at [docs.projectbluefin.io/images →](https://docs.projectbluefin.io/images/)

### Bluefin Dakota

Project Bluefin Dakota image stream.

```bash
# Latest
sudo bootc switch ghcr.io/projectbluefin/dakota:latest --enforce-container-sigpolicy
# Latest — NVIDIA
sudo bootc switch ghcr.io/projectbluefin/dakota-nvidia:latest --enforce-container-sigpolicy
```

## Getting Started

Download the latest ISO: **[dakota-live-latest.iso](https://projectbluefin.dev/dakota-live-latest.iso)** · [Checksum](https://projectbluefin.dev/dakota-live-latest.iso-CHECKSUM)

See [AGENTS.md](AGENTS.md) for the full contributor workflow, build instructions, and PR checklist.

**Known gaps:**
- Installation path is still being worked on
- Upgrades and rollbacks need more hardening

See [open issues](https://github.com/projectbluefin/dakota/issues) for where things stand.

## Built-in feedback loop

Dakota doesn't eat tickets, it treats them as evidence. Every user running Dakota is part of a structured loop that flows directly back into upstream GNOME, freedesktop, and the kernel.

| Command | What it does |
|---|---|
| `ujust report` | Captures your system state and opens a pre-filled issue. One command instead of a wall of "please attach logs." |
| `ujust confirm <issue>` | Adds a hardware fingerprint to an existing issue — no duplicate filing. |
| `ujust verify <issue>` | Confirms a fix works on your machine after it ships. Closes the loop with evidence. |

No telemetry. Every report is reviewed by you before it leaves your machine, lives in a gist you own, and can be deleted anytime. [Read the full design](docs/feedback-loop.md)

## The research behind it

Dakota's feedback loop model is grounded in Andy Anderson's work on autonomous AI-assisted software development:

- [The AI Codebase Maturity Model](https://arxiv.org/abs/2604.09388) — the arxiv paper
- [When AI agents become contributors](https://www.cncf.io/blog/2026/05/14/when-ai-agents-become-contributors-how-kubestellar-reached-81-pr-acceptance/) — CNCF blog
- [Beyond prompting: How KubeStellar reached 81% PR acceptance](https://thenewstack.io/ai-codebase-maturity-model/) — The New Stack

We coordinate via [KubeStellar Hive](https://github.com/kubestellar/hive). Humans make the final decisions.

## Help shape what gets built

These issues need human judgment before any code is written:

**[Issues open for discussion →](https://github.com/projectbluefin/dakota/issues?q=is%3Aopen+label%3Astatus%2Fdiscussing)**

Ready to build? See the [agent-ready queue](https://github.com/projectbluefin/dakota/issues?q=is%3Aopen+label%3Aqueue%2Fagent-ready+no%3Aassignee) for issues with clear acceptance criteria.

## Community

- 📰 **[Blog](https://blog.projectbluefin.io/)** — announcements and release posts
- 💬 **[Discussions](https://community.projectbluefin.io/)** — community forum
- 📋 **[Project Board](https://todo.projectbluefin.io/)** — what we're working on
- 📖 **[Documentation](https://docs.projectbluefin.io/)** — user guides and reference

## Contributing

See [AGENTS.md](AGENTS.md) for the contributor workflow and build instructions. All participants are expected to follow the [Universal Blue Community Guidelines](https://docs.projectbluefin.io/contributing#community-guidelines).

Report security vulnerabilities via [SECURITY.md](SECURITY.md).

## License

Apache License 2.0 — see [LICENSE](LICENSE).

Dakota incorporates [GNOME OS](https://os.gnome.org/), [freedesktop-sdk](https://gitlab.freedesktop.org/freedesktop-sdk/freedesktop-sdk), and various upstream projects, each under their respective licenses.
