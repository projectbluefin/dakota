# Contributing

Thanks for helping out.

## Dakota is BuildStream-first

Dakota is built with [BuildStream 2](https://buildstream.build/), not a Containerfile + DNF/RPM workflow.

- Change packages and image content through `elements/`, `files/`, and related BuildStream inputs.
- Use `just bst ...` instead of a host-installed `bst`.
- If the change really belongs in the shared base layer, start with `projectbluefin/common` and then verify Dakota's common-layer adjustments in `elements/bluefin/common.bst`.

For the durable system boundaries, read [`docs/architecture.md`](docs/architecture.md).

## Prerequisites

| Tool | Why |
|---|---|
| `podman` | BuildStream sandbox and OCI export flow |
| `just` | Stable entry point for local tasks |
| `qemu` | Local boot validation when you need VM-based proof |

Run `just --list` first. The `Justfile` is the command index for local work.

## Human contribution workflow

1. **Branch from `upstream/testing`.**
   ```bash
   git checkout upstream/testing -b fix/short-description
   ```
2. **Make the smallest focused change that solves the problem.**
3. **Run the lightest proof that matches the change.** See [`docs/qa.md`](docs/qa.md).
4. **Commit conventionally.** Use `<type>(<scope>): <description>`.
5. **Push to `upstream` and open the PR against `testing`.**
   ```bash
   git push upstream fix/short-description
   gh pr create --repo projectbluefin/dakota --base testing
   ```

`main` is a release bookmark updated by promotion automation. Do not open normal PRs against it.

## Commit trailer rule

New repository commits require an `Assisted-by:` trailer and must not use a
`Co-authored-by:` trailer. This rule applies to new work; do not rewrite
existing history to change its trailers.

## Evidence expectations by change type

| If you changed... | Minimum local evidence | Canonical reference |
|---|---|---|
| Markdown / documentation routing | `just docs-check` | [`docs/qa.md`](docs/qa.md) |
| BuildStream graph / element wiring | `just validate` | [`docs/qa.md`](docs/qa.md) |
| Junction patch state | `just patch-drift-check` + `just validate` | [`docs/architecture.md`](docs/architecture.md) |
| OCI/runtime image behavior | the smallest applicable set of `just build`, `just export`, `just lint`, `just boot-test` | [`docs/qa.md`](docs/qa.md) |
| Publish / release / rollback docs or workflows | targeted validation plus source review of the owning workflow or recipe | [`docs/release.md`](docs/release.md) |

## Pull request expectations

- Target `testing`.
- Include evidence for the commands you actually ran.
- Keep the diff focused to one logical change.
- Link the issue from the PR body with `Closes #NNN` when applicable.
- If you used an agent, keep the PR template accountability checkbox checked.

Release and trust details live in [`docs/release.md`](docs/release.md). The product issue lifecycle and data-donation loop live in [`docs/feedback-loop.md`](docs/feedback-loop.md).
