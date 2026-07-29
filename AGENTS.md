# AGENTS.md

Dakota is Project Bluefin's **BuildStream 2** repository for producing a bootc OCI desktop image from source.

- **Build model:** BuildStream elements and junctions, not RPM layering or Containerfiles.
- **Runtime model:** bootc + composefs, not rpm-ostree or an OSTree-managed host.
- **Product boundary:** Dakota consumes `projectbluefin/common` as a base layer, then adds Dakota-specific elements, files, and OCI assembly.

If your first instinct is to use `dnf`, `rpm-ostree`, edit a Containerfile, or patch a built image by hand, stop and re-read [`docs/architecture.md`](docs/architecture.md).

## Read order

Read the smallest set that fits the task:

1. [`README.md`](README.md) — product overview and top-level navigation
2. [`CONTRIBUTING.md`](CONTRIBUTING.md) — human branch/check/PR workflow
3. [`docs/architecture.md`](docs/architecture.md) — durable system boundaries
4. [`docs/qa.md`](docs/qa.md) — validation and evidence expectations
5. [`docs/release.md`](docs/release.md) — publish, trust, promotion, rollback
6. [`docs/feedback-loop.md`](docs/feedback-loop.md) — issue/data-donation model when working from reports
7. [`docs/skills/index.md`](docs/skills/index.md) — task routing for focused repo skills

## Stable command entry points

Use `just --list` first. These commands are the stable local entry points; mutable implementation details live in the `Justfile` and workflows they call.

| Command | Purpose |
|---|---|
| `just validate` | Validate the BuildStream graph and publish-workflow invariants |
| `just build [variant]` | Build the OCI image through BuildStream |
| `just export [variant]` | Export a built OCI artifact into podman |
| `just lint` | Run `bootc container lint` on the exported image |
| `just boot-test` | Run the automated local boot smoke test |
| `just docs-check` | Run the repository documentation-contract checker |

## Hard repository boundaries

- **PR base:** all normal work targets `upstream/testing`. `main` is a release bookmark, not a PR base.
- **Push remote:** push to `upstream`, never the personal fork, for projectbluefin/dakota work.
- **Use repo entry points:** prefer `just` recipes over ad-hoc host commands.
- **BuildStream only:** do not add `dnf`, `rpm-ostree`, or Containerfile-based build steps.
- **Common-layer boundary:** shared system content belongs in `projectbluefin/common`; Dakota-specific stripping or overrides belong in `elements/bluefin/common.bst`.
- **OCI layer rule:** files staged into `elements/oci/layers/` must produce filesystem output; `kind: compose` is the normal layer primitive.
- **Junction patch rule:** patch imported projects through the junction/patch queue flow, not by editing vendored upstream content in place.
- **Org safety rule:** never create issues, pull requests, comments, forks, dispatches, or other write actions against `ublue-os/*`.
- **Source-driven work:** when tool behavior matters, read the official docs first, then read the exact local file or workflow you are changing.

## Canonical references

| Topic | Canonical doc | Mutable source of truth |
|---|---|---|
| System structure | [`docs/architecture.md`](docs/architecture.md) | `project.conf`, `elements/`, `files/`, `Justfile` |
| Validation and evidence | [`docs/qa.md`](docs/qa.md) | `Justfile`, `.github/workflows/validate.yml`, `.github/workflows/e2e.yml` |
| Publish / trust / rollback | [`docs/release.md`](docs/release.md) | `.github/workflows/publish.yml`, `.github/workflows/execute-release.yml`, `.github/workflows/rollback-stable.yml`, `Justfile` |
| Product feedback loop | [`docs/feedback-loop.md`](docs/feedback-loop.md) | issue templates, Actionadon automation, `ujust` commands |
| Task routing | [`docs/skills/index.md`](docs/skills/index.md) | focused skill files under `docs/skills/` |

## Human decision gates

Stop and ask a maintainer before proceeding when the task crosses one of these lines:

- **Design gate:** new subsystem design or user-visible behavior changes
- **Security gate:** signing, credentials, auth, supply-chain, or trust-boundary changes
- **Breakage gate:** cross-repo breaking changes, renamed inputs, changed defaults, or new consumer requirements
- **Merge gate:** final approval and merge always belong to a human maintainer

## CI pre-flight before CI actions

Before pushing, merging, or dispatching a workflow, verify the field is clear:

```bash
gh run list --repo projectbluefin/dakota --limit 30 \
  --json databaseId,status,name,headBranch \
  | python3 -c "
import json, sys
runs = json.load(sys.stdin)
active = [r for r in runs if r['status'] in ('in_progress', 'queued', 'pending', 'waiting')]
if active:
    print(f'BLOCKED: {len(active)} active run(s). Cancel all before proceeding:')
    for r in active:
        print(f'  gh run cancel {r["databaseId"]} --repo projectbluefin/dakota  # {r["name"]} [{r["headBranch"]}]')
else:
    print('OK: field is clear, safe to proceed')
"
```

If the output is not `OK: field is clear`, stop, cancel the active runs, and re-check before starting new CI work.
