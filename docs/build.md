# Build reference

## Requirements

| Tool | Why | Install |
|---|---|---|
| `podman` (rootful + rootless) | BST container + export/boot | Pre-installed on Bluefin |
| `just` | All build/test commands | Pre-installed on Bluefin |
| `qemu` | VM boot | `brew install qemu` |
| `virtiofsd` | `just boot-fast` only | `rpm-ostree install virtiofsd` then reboot |
| `bcvk` | Ephemeral VM from container | Auto-installed by `just boot-fast` via cargo |
| ~100 GB disk, ~16 GB RAM | BST cache + parallel builds | — |

## Repo layout

| Path | Purpose |
|---|---|
| `elements/freedesktop-sdk.bst` | fdsdk junction — pinned to a release tag |
| `elements/gnome-build-meta.bst` | GBM junction — tracks `gnome-50` branch |
| `elements/bluefin/` | Bluefin-specific elements (~40 elements) |
| `elements/oci/` | OCI image assembly — layers + final image |
| `patches/freedesktop-sdk/` | Patches applied to fdsdk via `patch_queue` |
| `patches/gnome-build-meta/` | Patches applied to GBM via `patch_queue` |
| `patches/linux/` | Kernel patches (via fdsdk linux element) |
| `files/` | Static files installed by elements |
| `docs/skills/` | Agent skills — task-focused, lazy-loaded |
| `Justfile` | All local dev commands — run `just --list` first |

## Dev loop

```bash
just validate                  # graph check — always run first (~5 min, no build)

export BUILD_SKIP_NVIDIA=1
just build default             # build image — warm cache: 2–5 min; cold: 60–90 min

just lint                      # bootc container lint — must pass before PR

just boot-test                 # automated smoke test — exits 0 on success
just boot-fast                 # interactive ephemeral VM via virtiofs (requires virtiofsd)

just show-me-the-future        # full loop: build → export → disk image → QEMU VM
```

First run is slow (cold BST cache). Subsequent runs are fast — BST caches by content hash.

## Useful BST commands

```bash
just validate                                           # check element graph
just bst build elements/bluefin/tailscale.bst          # build one element
just bst shell --build elements/bluefin/tailscale.bst  # sandbox shell
just bst show --deps all oci/bluefin.bst               # full dependency graph
```

## What NOT to do

| Don't | Why |
|---|---|
| `rpm-ostree`, `pip install`, `apt-get` in elements | BST-only build; all deps from junctions |
| `$(date)`, `$(hostname)`, `$(curl ...)` in `install-commands` | Breaks reproducibility and BST caching |
| Patch junction files directly | Use `patch_queue` source in the junction `.bst` |
| Force-push to `main` | The merge queue owns merges |
| Close issues via API or comment | Use `Closes #NNN` in the PR body |
| Open a PR without running `just validate` | Wastes everyone's time |
