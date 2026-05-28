Dakota is built entirely from source — no RPMs, no dnf. Pure BuildStream.
`ujust report` collects structured diagnostics and uploads to your own gist — you review everything first.
`ujust confirm <issue>` tells maintainers "me too" with your hardware fingerprint attached.
`ujust verify <issue>` attests whether a shipped fix actually works on your machine.
Hit a bug? Run `ujust report` — structured data helps maintainers fix things faster.
Dakota uses atomic OCI updates via `bootc` — your system is always a known-good image.
Update break something? Roll back instantly with `bootc rollback`.
Use Goose + linux-mcp-server for AI-powered troubleshooting — it reads your system state live.
`ujust --choose` shows every available shortcut and the script it runs.
`ujust bluefin-cli` sets up your terminal with curated developer tools.
`ujust check-idle-power-draw` measures your system's power consumption at idle.
`ujust benchmark` runs a one-minute stress test to baseline your hardware.
`brew search` and `brew install` manage command line packages — updates are automatic.
Container development is first-class: devcontainers, Podman, and DistroShelf are all ready to go.
Your feedback closes the loop: report → fix → verify → done. Every `ujust verify` is evidence.
Dakota ships the same test suite contributors use — `ujust report` is your entry point.
