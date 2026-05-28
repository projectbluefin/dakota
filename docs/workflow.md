# Community workflow

## Issue flow

`status/discussing` → `status/approved` (maintainer writes acceptance criteria) → `queue/agent-ready` → `/claim` → implement → PR with `Closes #NNN` → merge queue.

## Actionadon bot

| Comment | Effect |
|---|---|
| `/claim` | Assigns you, adds `queue/claimed` |
| `/ready` | Moves approved+spec-complete issue into the queue (wranglers/maintainers only) |
| `/unclaim` | Returns to the queue |

**`kind:agent-donation` issues:** write the report as a comment, cite sources, close the issue. Do not open a PR.

## Hive

Copy `files/hive/hive-project.yaml.example` to `/etc/hive/hive-project.yaml` and load `files/hive/agent-policies/` as per-agent CLAUDE.md overrides.

## Labels

| Label | Meaning |
|---|---|
| `status/discussing` | Not ready for the agent queue |
| `status/approved` | Approved; needs acceptance criteria before queue |
| `queue/agent-ready` | Scoped with acceptance criteria — claim it |
| `queue/claimed` | In active work |
| `agent/blocked` | Needs human input before work can continue |
| `hold` | Do not touch |
| `do-not-merge` | Do not merge or automate |
| `lgtm` | Maintainer approved |
| `lab:pass` | Lab validation passed; enables label-gated auto-merge |
| `kind:bug` / `kind:improvement` / `kind:tech-debt` / `kind:github-action` | Change type |
| `kind:agent-donation` | Investigation request — report comment, not code |
| `flow/project-report` / `flow/issue-review` / `flow/pr-review` | Hive scanner flow routing |
| `needs-human/agent-oops` | Agent error — do not remove; note what went wrong in your reply |

**Hive exempt** (do not touch): `hold`, `do-not-merge`, `status/discussing`, `status/approved`, `queue/claimed`, `agent/blocked`, `needs-human/agent-oops`, `duplicate`, `wontfix`, `stale`

## Links

- [BuildStream docs](https://docs.buildstream.build/)
- [freedesktop-sdk](https://gitlab.com/freedesktop-sdk/freedesktop-sdk)
- [gnome-build-meta](https://github.com/GNOME/gnome-build-meta) — branch `gnome-50`
- [Dakota issues](https://github.com/projectbluefin/dakota/issues)
- [Dakota board](https://github.com/orgs/projectbluefin/projects/3)
- [All Bluefin projects](https://github.com/orgs/projectbluefin/projects/2)
