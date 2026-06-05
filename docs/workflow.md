# Community workflow

## Issue flow

`filed → approved → queued → claimed → done`

| Stage | Meaning |
|---|---|
| `filed` | Issue opened and `status/triage` applied |
| `approved` | `status/approved` added by a maintainer |
| `queued` | `status/queued` is added automatically with `status/approved` |
| `claimed` | `status/claimed` |
| `done` | Issue closed after three verifies or maintainer override |

### Pipeline widget

Actionadon keeps the pipeline widget in the issue body and rewrites it in place at every stage.

#### Filed

```text
DAKOTA  ·  issue pipeline
─────────────────────────────────────────────────
  ▶  filed      report received
  ·  approved   —
  ·  queued     —
  ·  claimed    —
  ·  done       —
─────────────────────────────────────────────────
  report:       attached/missing  ·  confirms: N
  area:         name              ·  priority: name
  next action:  same bug? ujust confirm NNN
```

#### Approved

```text
DAKOTA  ·  issue pipeline
─────────────────────────────────────────────────
  ✓  filed      report received
  ▶  approved   cleared for the build queue
  ·  queued     —
  ·  claimed    —
  ·  done       —
─────────────────────────────────────────────────
  report:       attached/missing  ·  confirms: N
  area:         name              ·  priority: name
  next action:  comment /claim to take this
```

#### Queued

```text
DAKOTA  ·  issue pipeline
─────────────────────────────────────────────────
  ✓  filed      report received
  ✓  approved   cleared for the build queue
  ▶  queued     open for contributors
  ·  claimed    —
  ·  done       —
─────────────────────────────────────────────────
  report:       attached/missing  ·  confirms: N
  area:         name              ·  priority: name
  next action:  comment /claim to take this
```

#### Claimed

```text
DAKOTA  ·  issue pipeline
─────────────────────────────────────────────────
  ✓  filed      report received
  ✓  approved   cleared for the build queue
  ✓  queued     open for contributors
  ▶  claimed    @username
  ·  done       —
─────────────────────────────────────────────────
  report:       attached/missing  ·  confirms: N
  area:         name              ·  priority: name
  next action:  /unclaim to return to queue if stuck
```

#### Done

```text
DAKOTA  ·  issue pipeline
─────────────────────────────────────────────────
  ✓  filed      report received
  ✓  approved   cleared for the build queue
  ✓  queued     open for contributors
  ✓  claimed    @username
  ▶  done       fix shipped
─────────────────────────────────────────────────
  report:       attached/missing  ·  verified: N/3
  area:         name              ·  priority: name
  next action:  ujust verify NNN — three verifies closes the case
```

Metadata rows are pulled live from GitHub at every transition:

- `report:` — gist URL present in the body shows `attached`; no gist URL shows `missing`
- `confirms:` — count of comments containing `ujust confirm` on open issues
- `verified:` — count of comments containing `ujust verify`, shown as `N/3` on closed issues
- `area:` — extracted from `area/*` labels
- `priority:` — extracted from `priority/*` labels

### Triage signals

- `report: attached` means the full telemetry bundle is already there. Prioritize it over issues without a report and do not ask for data already in the gist.
- `confirms: N` means N distinct hardware instances reproduced it. Treat high counts as higher priority.
- `verified: N/3` drives closure. Do not close the issue until it hits 3 or a maintainer explicitly overrides it.
- High priority plus no assignee is a good immediate claim target.

### Data donation pattern

`ujust report` is a deliberate data donation. The reporter reviews the gist before filing, keeps ownership of it, and can delete it later. That is not telemetry.

`ujust confirm` adds another hardware instance without opening a duplicate. `ujust verify` adds post-fix evidence on real hardware and moves the issue toward closure.

**`flow/agent-donation` issues:** write the report as a comment, cite sources, close the issue. Do not open a PR.

## Actionadon bot

| Comment | Who can use it | Effect |
|---|---|---|
| `/claim` | anyone | Adds `status/claimed`, assigns the commenter |
| `/unclaim` | assignee or write+ | Removes `status/claimed`, unassigns |
| `/approve` or `/lgtm` | write+ | Adds `lgtm` |

The widget lives in the issue body and is updated in place. Zero pipeline comments. One edit per stage.

`<!-- actionadon-pipeline -->` is the sentinel block Actionadon uses to find the widget. Do not remove it by hand.

Adding `status/approved`, or using `/approve` or `/lgtm`, also auto-queues the issue by adding `status/queued`.

## Hive

Copy `files/hive/hive-project.yaml.example` to `/etc/hive/hive-project.yaml` and load `files/hive/agent-policies/` as per-agent CLAUDE.md overrides.

## Labels

| Label | Meaning |
|---|---|
| `status/triage` | Needs human review — set kind, priority, and area |
| `status/discussing` | Not ready for the agent queue |
| `status/approved` | Approved — ready for contributors |
| `status/queued` | Has a spec, ready to claim — comment `/claim` |
| `status/claimed` | In active work — comment `/unclaim` to return |
| `agent/blocked` | Blocked — needs human input before work can continue |
| `hold` | Do not touch |
| `do-not-merge` | Do not merge or automate |
| `lgtm` | Maintainer approved — ready to merge |
| `tests:pass` | e2e tests passed; enables label-gated auto-merge |
| `kind:bug` / `kind:improvement` / `kind:tech-debt` / `kind:github-action` | Change type |
| `flow/agent-donation` | Investigation request — report comment, not code |
| `flow/project-report` / `flow/issue-review` / `flow/pr-review` | Hive scanner flow routing |
| `needs-human/agent-oops` | Agent error — do not touch; humans only |

**Hive exempt** (do not touch): `hold`, `do-not-merge`, `status/discussing`, `status/approved`, `status/claimed`, `agent/blocked`, `needs-human/agent-oops`, `duplicate`, `wontfix`, `stale`

## Image stream and branch model

Dakota publishes three streams from the `main` branch:

```
main (source of truth)
  │
  └─► build.yml (nightly + merge_group + workflow_dispatch)
          │
          └─► publish.yml (workflow_run on build success)
                  │
                  ├─► :sha     — immutable per-build tag
                  └─► :testing — promoted after e2e smoke passes
                                       │
                              weekly-testing-promotion.yml
                              (Sunday 06:00 UTC, production environment approval)
                                       │
                                       ├─► :latest  (+ fast-forwards latest branch)
                                       └─► :stable  (+ fast-forwards stable branch)
```

| Stream | Tag | Cadence | Gate |
|---|---|---|---|
| Development | `:sha` | Every merge to `main` | None |
| Testing | `:testing` | Nightly | e2e smoke |
| Latest | `:latest` | Weekly (Sunday) | production environment approval |
| Stable | `:stable` | Weekly (Sunday) | Same as `:latest` |

**All code merges to `main`.** The `:testing` Docker tag is the published nightly result built from `main`. The `testing`, `latest`, and `stable` git branches are bookmarks fast-forwarded by the promotion workflows — they are not development branches.

**Branch protection is only on `main`.** Required status checks: `validate` + `e2e`.

### Branch flow for contributors

```bash
# Branch from upstream/main (never fork's local main)
git checkout upstream/main -b feat/my-change

# Work, validate, commit
just validate
git commit -m "feat(bluefin): ..."

# Push and open PR against main
git push upstream feat/my-change
gh pr create --repo projectbluefin/dakota --base main
```


- [freedesktop-sdk](https://gitlab.com/freedesktop-sdk/freedesktop-sdk)
- [gnome-build-meta](https://github.com/GNOME/gnome-build-meta) — branch `gnome-50`
- [Dakota issues](https://github.com/projectbluefin/dakota/issues)
- [Dakota board](https://github.com/orgs/projectbluefin/projects/3)
- [All Bluefin projects](https://github.com/orgs/projectbluefin/projects/2)
