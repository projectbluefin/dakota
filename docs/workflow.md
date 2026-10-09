# Community workflow

## Issue flow

`filed → needs-triage → triage accepted → done`

| Stage | Meaning |
|---|---|
| `filed` | Issue opened; `needs-triage` applied automatically by Prow |
| `categorized` | `/area <area>` or `/kind <kind>` applied by contributor or triager |
| `triage accepted` | `triage/accepted` added via `/triage accepted` by maintainer or triage team |
| `done` | Issue closed after three verifies or maintainer override |

### Triage signals

- Issues open with `needs-triage` until accepted with `/triage accepted`
- Issues must have a kind label (`kind/bug`, `kind/feature`, etc.) or Prow applies `needs-kind`
- Categorization is managed via `/area <area>`
- Priority is assigned via `/priority critical-urgent` or `/priority important-soon`
- `report: attached` means the diagnostic bundle from `ujust report` is present. Prioritize it over reports without diagnostic data
- Multiple user confirmations (`ujust confirm`) indicate reproduction across distinct hardware instances
- Post-fix evidence on hardware (`ujust verify`) helps maintainers confirm bug resolution
### Data donation pattern

`ujust report` is a deliberate data donation. The reporter reviews the gist before filing, keeps ownership of it, and can delete it later. That is not telemetry.

`ujust confirm` adds another hardware instance without opening a duplicate. `ujust verify` adds post-fix evidence on real hardware and moves the issue toward closure.

**`flow/agent-donation` issues:** write the report as a comment, cite sources, close the issue. Do not open a PR.

## Prow bot

Dakota uses Prow (`.github/workflows/prow.yml`) backed by `projectbluefin/.project/prow.yaml`.

| Comment | Who can use it | Effect |
|---|---|---|
| `/kind <kind>` | anyone | Adds `kind/<kind>` (`bug`, `regression`, `security`, `feature`, `documentation`, `cleanup`) |
| `/area <area>` | anyone | Adds `area/<area>` (`desktop`, `flatpak`, `gaming`, `hardware`, `installer`, `dx`) |
| `/triage accepted` | triage team / maintainers | Adds `triage/accepted`, clearing `needs-triage` |
| `/priority <priority>` | triage team / maintainers | Sets `priority/critical-urgent` or `priority/important-soon` |
| `/label blocked` | triage team / maintainers | Adds `blocked` label |
| `/hold` | anyone | Adds `hold` label |
| `/assign [@user]` | anyone | Assigns contributor or self |
| `/unassign [@user]` | anyone | Unassigns contributor or self |
| `/lgtm` | approvers in OWNERS | Approves PR / marks LGTM |
| `/approve` | approvers in OWNERS | Records approval in OWNERS hierarchy |

## Hive

Copy `files/hive/hive-project.yaml.example` to `/etc/hive/hive-project.yaml` and load `files/hive/agent-policies/` as per-agent CLAUDE.md overrides.

## Labels

| Label | Meaning |
|---|---|
| `needs-triage` | Awaiting triage — comment `/triage accepted` |
| `needs-kind` | Missing kind — comment `/kind <kind>` |
| `triage/accepted` | Scope accepted; ready for work |
| `priority/critical-urgent` | Urgent priority |
| `priority/important-soon` | High priority |
| `kind/bug` / `kind/feature` / `kind/cleanup` / `kind/documentation` / `kind/regression` / `kind/security` | Change category |
| `area/desktop` / `area/flatpak` / `area/gaming` / `area/hardware` / `area/installer` / `area/dx` | Area of codebase |
| `blocked` | Blocked on human input or external dependency |
| `hold` | Paused work; do not merge or automate |
| `do-not-merge` | Do not merge |
| `lgtm` | Approved by maintainer / reviewer |
| `approved` | Approved by OWNERS approver |
| `tests:pass` | e2e tests passed |
| `flow/agent-donation` | Investigation request — report comment, not code |
| `flow/project-report` / `flow/issue-review` / `flow/pr-review` | Hive scanner flow routing |
| `needs-human/agent-oops` | Agent error — do not touch; humans only |
| `stream/next` / `stream/testing` | Set by `ujust report` from booted image tag |

## Image stream and branch model

Dakota uses trunk-based development. `testing` is the default branch and
integration trunk. Changes merge there; `sync-next.yml` synthesizes `next`
from testing plus its stream-specific overlay. Stable promotion selects a
published testing commit SHA, not a commit from `main`.

```text
testing change or daily schedule
  → build.yml
  → publish.yml on successful build
      ├─ :sha
      └─ :testing

testing merge
  → sync-next.yml
  → next + next-stream overlay (separate rolling stream)

just release (default: preflight only)
  → successful publish for testing SHA + default-image digest comparison
just release --apply
  → signature checks and digest-based promotion
  → :stable + GitHub release
```

`next` follows the same build/publish machinery but advances `:next` and `:btw`;
it never promotes to `:stable`. E2e is manually dispatched against an already
published image and is not a pull-request check.

**All normal PRs target `testing`.** Stable promotion does not move `main` or
require any merge into it. Post-release verification checks the published image
digests directly against the selected testing SHA. See [the CI reference](ci.md#stable-release)
for preflight limitations and recovery-SHA handling. Confirm live branch
protection and required checks in GitHub rather than copying them into
documentation.

### Branch flow for contributors

```bash
# Branch from upstream/testing (the development trunk)
git checkout upstream/testing -b feat/my-change

# Work, validate, commit
just validate
git commit -m "feat(bluefin): ..."

# Push and open PR against testing
git push upstream feat/my-change
gh pr create --repo projectbluefin/dakota --base testing
```


- [freedesktop-sdk](https://gitlab.com/freedesktop-sdk/freedesktop-sdk)
- [gnome-build-meta](https://github.com/GNOME/gnome-build-meta) — branch `gnome-50`
- [Dakota issues](https://github.com/projectbluefin/dakota/issues)
- [Dakota board](https://github.com/orgs/projectbluefin/projects/3)
- [All Bluefin projects](https://github.com/orgs/projectbluefin/projects/2)
