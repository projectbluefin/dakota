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
| `patches/linux/` | Kernel patches (via fdsdk linux element) |
| `files/` | Static files installed by elements |
| `.agents/skills/` | Agent skills — discovered and loaded on demand |
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
just validate                                        # check element graph
just bst build bluefin/tailscale.bst                 # build one element
just bst shell --build bluefin/tailscale.bst         # sandbox shell
just bst show --deps all oci/bluefin.bst             # full dependency graph
```

## Fastfetch ownership

`bluefin/common.bst` installs the fastfetch config and wrapper from its pinned
`projectbluefin/common` source. Do not copy the layout into Dakota or snapshot
its icons/colors in tests. Common updates should carry presentation changes
without a second sync step.

The temporary `patches/common/0001-fastfetch-install-date.patch` changes only
the date command to read the first-boot record. Drop it when common supports
that record through a shared helper. `firstboot-date.bst` owns the runtime
records, not the presentation; `nerd-fonts-symbols.bst` supplies icon fallback
without changing the default text font. The existing booted-image helper patch
in `common.bst` is separate and remains until common supports that record too.

Run `just bst build bluefin/common.bst` to exercise the patch against the pinned
source. A source rewrite that invalidates the patch must be reviewed, not
worked around by restoring a local config. Check glyph rendering in a booted
image.
The common source import also does not supply `fastfetch-user-count` or
`bazaar-install-count`; those weekly-statistics inputs remain a separate parity
gap, not a reason to fork the config or invent counts.

## What NOT to do

| Don't | Why |
|---|---|
| `rpm-ostree`, `pip install`, `apt-get` in elements | BST-only build; all deps from junctions |
| `$(date)`, `$(hostname)`, `$(curl ...)` in `install-commands` | Breaks reproducibility and BST caching |
| Patch junction files directly | Use `patch_queue` source in the junction `.bst` |
| Force-push to `main` | `main` is a release bookmark; `execute-release.yml` is the only writer |
| Close issues via API or comment | Use `Closes #NNN` in the PR body |
| Open a PR without running `just validate` | Wastes everyone's time |
