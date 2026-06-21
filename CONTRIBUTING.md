# CONTRIBUTING

Thanks for helping out!

## ⚠️ Dakota uses BuildStream 2 — not Containerfiles

Dakota is built with **[BuildStream 2](https://buildstream.build/)** (BST), not a Containerfile or DNF/RPM like mainline Bluefin. If you're here to change something in the Bluefin image, you probably want [`projectbluefin/common`](https://github.com/projectbluefin/common) instead.

If you're here to package new software for the BST-based image, read [`AGENTS.md`](AGENTS.md) first — all build instructions, BST workflow, PR checklist, branch conventions, and mandatory gates live there. The README also references AGENTS.md.

Check the [Contributing Guide](https://docs.projectbluefin.io/contributing) for general contribution information and [the architecture diagram](https://docs.projectbluefin.io/contributing#understanding-bluefins-architecture).

## Prerequisites

- [`bst`](https://buildstream.build/) (BuildStream 2) — `pip install buildstream`
- `podman` — required for BST sandbox execution
- `just` — `brew install just` or your OS package manager

## Pull requests

- Open PRs against the `testing` branch
- Run `just check` before opening a PR
- Follow [Conventional Commits](https://www.conventionalcommits.org/) for commit messages

## Where things live

```
project.conf          # BST project configuration
elements/             # BST element files (.bst) — one per package
junctions/            # BST junction manifests (upstream source pins)
system_files/         # Files overlaid into the final OCI image
```

Full build reference and BST workflow: [`AGENTS.md`](AGENTS.md)
