> Read `AGENTS.md` and `docs/skills/README.md` before any work.
>
> **In-repo skills (version-controlled, always current — load these first):**
> - ujust recipes and gum patterns: `.github/skills/ujust-recipes.md`
> - Testlab patterns (bootc switch, assertions): `docs/skills/testlab.md`
> - Agent role policies (Hive): `files/hive/agent-policies/`
> - Full skill index: `docs/skills/README.md`

## Build commands

```bash
just bst build oci/bluefin.bst   # full image build (inside bst2 container)
just build                        # alias for the above
just export                       # export OCI image from BST into podman
just lint                         # bootc container lint (requires exported image)
just bst show oci/bluefin.bst     # inspect element dependency graph
```

Builds run inside the pinned `bst2` container. `BST_FLAGS` env var injects flags:

```bash
just bst build oci/bluefin.bst
```

## ⚠️ Hard rules (learned from real mistakes)

### 1. Always branch from upstream/main

```bash
git checkout upstream/main -b feature/my-change
```

**Never branch from local `main`.** The `castrojo/dakota` fork diverges from `projectbluefin/dakota` by 20+ commits. Branching from local `main` creates PRs with hundreds of unrelated files.

Verify before pushing:
```bash
git diff upstream/main...HEAD --stat
```

### 2. cargo2 source blocks are generated — never hand-written

```bash
python3 files/scripts/generate_cargo_sources.py path/to/Cargo.lock
```

The first ~65 lines of a Rust BST element are hand-authored (build commands, install paths). Everything after that is generated crate manifest. Do not write crate entries by hand.

### 3. Layer elements must be `kind: compose`, not `kind: stack`

Elements staged as `/layer` in OCI script elements **must** be `kind: compose`. `kind: stack` is a dependency aggregator that produces **zero filesystem output** — the image builds successfully but the layer is silently empty.

```yaml
# ✅ correct — produces filesystem content
kind: compose

# ❌ wrong — silently empty layer
kind: stack
```

### 4. No /issues/NNN paths in issue bodies

GitHub autolinks `org/repo#NNN` and `/issues/NNN` paths regardless of code fence context, firing cross-repo notifications. Write upstream references as plain text:

```
# ✅ correct
bootc-dev/bootc issue 7

# ❌ wrong — spams the other repo
https://github.com/bootc-dev/bootc/issues/7
```

## CI overview

- **Schedule:** nightly at 13:00 UTC (after gnome-build-meta nightly ~08:00 UTC finish)
- **Publish triggers:** `merge_group`, `schedule`, `workflow_dispatch` (not `pull_request`)
- **Remote cache:** `cache.projectbluefin.io:11002` (mTLS — `CASD_CLIENT_CERT` + `CASD_CLIENT_KEY`)
- **Image:** `ghcr.io/projectbluefin/dakota:latest` and `:<sha>`

## Key architecture

- Built on gnome-build-meta + freedesktop-sdk via BST junctions
- `elements/bluefin/deps.bst` (`kind: stack`) — add new packages here
- `elements/oci/layers/` — compose chain filters artifacts into the final layer
- `elements/oci/bluefin.bst` — final OCI assembly script
- `patches/gnome-build-meta/` — drop `.patch` files here (alphabetical order, no edits to `gnome-build-meta.bst`)
