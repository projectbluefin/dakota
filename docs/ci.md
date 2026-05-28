# CI reference

## Jobs

| Job | Triggers | What |
|---|---|---|
| `validate` | `pull_request` | `bst show` — graph + patch check (~5 min) |
| `build` | `merge_group`, `schedule`, `workflow_dispatch` | Full OCI build (~60–90 min) |
| `build-aarch64` | disabled | ARM64 — pending investigation |

## Schedule

**13:00 UTC** daily — runs after GBM nightly (~08:00 UTC finish).

## Remote cache

`cache.projectbluefin.io:11002` — mTLS via `CASD_CLIENT_CERT` + `CASD_CLIENT_KEY`.

## Published images

`ghcr.io/projectbluefin/dakota:latest` and `ghcr.io/projectbluefin/dakota:<sha>`

Build triggers: `merge_group`, `schedule`, `workflow_dispatch` — **not** `pull_request`.

Never bypass the merge queue with `--admin`.
