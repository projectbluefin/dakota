# Bluefin Dakota
*Dakotaraptor steini*

[Bluefin](https://projectbluefin.io) built on [GNOME OS](https://os.gnome.org/), assembled entirely from source.
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/projectbluefin/dakota)


## Features

Dakota is the flagship Bluefin desktop. Compared with previous images such as Bluefin Classic, it offers:

- The latest GNOME desktop
- System libraries and development tools from the Freedesktop SDK
- Optimized x86-64-v3 builds for modern CPUs
- systemd-boot as the bootloader, with full Secure Boot support
- A dedicated gaming session with a gaming kernel from the Open Gaming Collective and Steam Gamescope
- uutils as the default coreutils implementation
- A graphical Control Center for system administration

## Built-in feedback loop

Dakota doesn't eat tickets; it treats them as evidence. Every user running Dakota is part of a structured loop that feeds directly back into the issue tracker. When something breaks on your hardware, you have three commands:

| Command | What it does |
|---|---|
| `ujust report` | Captures your system state and opens a pre-filled issue. One command instead of a wall of "please attach logs." |
| `ujust confirm <issue>` | Tells the team your hardware hits the same bug. Adds a hardware fingerprint to the issue — no duplicate filing. |
| `ujust verify <issue>` | After a fix ships in a nightly, confirms it works on your machine. Closes the loop with evidence. |

No telemetry. No phone-home. You review every report before it leaves your machine. Reports live in gists you own and can delete at any time.

## Image streams

|        Tag |  Stream |                                                                                                    What it is |
| ---------: | ------: | ------------------------------------------------------------------------------------------------------------: |
|  `:stable` |  Stable |                                                     GNOME 51 — production. Weekly promotions from `:testing`. |
| `:testing` |     Dev |                                              GNOME 51 — daily builds from the `testing` branch. Boot-check gated. |
|    `:next` | Rolling |                                       Tracks gnome-build-meta `master` daily (currently disabled).            |

## ISO Download

[dakota-live-latest.iso](https://projectbluefin.dev/dakota-live-latest.iso) · [Checksum](https://projectbluefin.dev/dakota-live-latest.iso-CHECKSUM)

## Secure Boot

- Run: `ujust enroll-secure-boot-key`
- Check EAC readiness: `ujust check-anticheat`

## Known gaps

See the [open issues](https://github.com/projectbluefin/dakota/issues) for where things stand.

## Contributing or building from source

See [AGENTS.md](AGENTS.md) for the full contributor workflow, build instructions, and PR checklist.

![Dakotaraptor](https://github.com/user-attachments/assets/ee92291d-a617-496e-abb6-9045a4c665ce)
