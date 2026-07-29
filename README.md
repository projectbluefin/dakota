# Bluefin Dakota
*Dakotaraptor steini*

[Bluefin](https://projectbluefin.io) built on [GNOME OS](https://os.gnome.org/), assembled entirely from source.

<a href="https://docs.projectbluefin.io/changelogs">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://docs.projectbluefin.io/img/cards/dakota-dark.png">
    <img src="https://docs.projectbluefin.io/img/cards/dakota-light.png" alt="Bluefin Dakota" width="800">
  </picture>
</a>

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/projectbluefin/dakota)

**Alpha** — [filing issues](https://github.com/projectbluefin/dakota/issues) is the whole point.

## Start here

| I need to... | Read |
|---|---|
| Understand what Dakota is and how it is assembled | [`docs/architecture.md`](docs/architecture.md) |
| Contribute, branch, validate, and open a PR | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| Understand validation and proof expectations | [`docs/qa.md`](docs/qa.md) |
| Verify publish, signatures, SBOMs, promotion, or rollback | [`docs/release.md`](docs/release.md) |
| Understand the product feedback-loop model | [`docs/feedback-loop.md`](docs/feedback-loop.md) |
| Route an agent task to the right focused repo skill | [`docs/skills/index.md`](docs/skills/index.md) |
| Load hard repository boundaries for agents | [`AGENTS.md`](AGENTS.md) |

## Built-in feedback loop

Dakota treats bug reports as evidence, not queue noise.

Every user running Dakota has three core commands:

| Command | What it does |
|---|---|
| `ujust report` | Captures system state and opens a pre-filled issue for review |
| `ujust confirm <issue>` | Adds another hardware confirmation without filing a duplicate |
| `ujust verify <issue>` | Verifies that a shipped fix actually works on real hardware |

No telemetry. No phone-home. Reports are reviewed before they leave the machine and stay user-owned.

See [`docs/feedback-loop.md`](docs/feedback-loop.md) for the full model.

## Help shape what gets built

**Architects and designers** — these features and epics need input before code is written:

### [Open features and epics for discussion →](https://github.com/projectbluefin/dakota/issues?q=is%3Aopen+label%3Astatus%2Fdiscussing+label%3Atype%2Ffeature%2Ckind%2Fepic)

**Engineers** — these issues have clear acceptance criteria and are ready to build:

### [Agent-ready build queue →](https://github.com/projectbluefin/dakota/issues?q=is%3Aopen+label%3Astatus%2Fqueued+no%3Aassignee)

## Image streams

| Tag | Stream | What it is |
|---|---|---|
| `:stable` | Stable | Production tag promoted from a previously published `:testing` build |
| `:testing` | Development | The main development stream from the `testing` branch |
| `:next` | Rolling | GNOME master / rolling branch build |
| `:btw` | Rolling | Alias for `:next` |

Release, trust, promotion, and rollback details live in [`docs/release.md`](docs/release.md).

## ISO download

[dakota-live-latest.iso](https://projectbluefin.dev/dakota-live-latest.iso) · [Checksum](https://projectbluefin.dev/dakota-live-latest.iso-CHECKSUM)

## Contributing or building from source

Use [`CONTRIBUTING.md`](CONTRIBUTING.md) for the contributor workflow, [`docs/qa.md`](docs/qa.md) for proof requirements, and [`AGENTS.md`](AGENTS.md) for hard repository boundaries.

![Dakorator](https://github.com/user-attachments/assets/ee92291d-a617-496e-abb6-9045a4c665ce)
