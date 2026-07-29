---
name: bluefin-cli
description: The Bluefin CLI developer container — a systemd-nspawn machine shipping Homebrew as an immutable OS component. Load when working on elements/bluefin/bluefin-cli.bst, files/bluefin-cli/*, or debugging container initialization.
---

# Bluefin CLI

## Overview

Bluefin CLI is a versioned, signed nspawn container (Ubuntu 24.04 + systemd + Homebrew) delivered alongside the Dakota OCI image. It runs as a persistent system machine via `machinectl`. A host wrapper (`/usr/bin/brew`) transparently proxies commands into the container. Packages persist in `/home/linuxbrew` across container image updates.

## When to use

- Editing `elements/bluefin/bluefin-cli.bst` or any file in `files/bluefin-cli/`.
- Debugging container initialization, the brew wrapper, or sysupdate integration.
- Understanding why `PrivateUsers=no` is required and what that implies.

## When not to use

- General BST element syntax → [buildstream](../buildstream/SKILL.md)
- OCI image assembly → [oci-layers](../oci-layers/SKILL.md)
- Adding host-level packages → [add-package](../add-package/SKILL.md)

## Authoritative sources

- `files/bluefin-cli/homebrew.nspawn` — nspawn config (security settings, bind mounts)
- `files/bluefin-cli/brew` — host wrapper script
- `files/bluefin-cli/bluefin-cli-init.service` — firstboot service
- `files/bluefin-cli/homebrew-container.transfer` — systemd-sysupdate transfer config
- `elements/bluefin/bluefin-cli.bst` — BST element installing all of the above

## Workflow

1. **Edit config files** in `files/bluefin-cli/`.
2. **Verify the element installs them to the right paths** by reading `elements/bluefin/bluefin-cli.bst` install-commands.
3. **Validate**: `just bst show bluefin/bluefin-cli.bst` (must parse cleanly).
4. **Test brew wrapper logic** by reading `files/bluefin-cli/brew` — it uses `systemd-run --machine=homebrew` to proxy into the container.

### Architecture

```
Host image ships:
  /etc/systemd/nspawn/homebrew.nspawn         ← container config
  /usr/lib/systemd/system/bluefin-cli-init.service  ← firstboot pull+import
  /usr/lib/sysupdate.bluefin-cli.d/homebrew-container.transfer
  /usr/bin/brew                               ← host wrapper

First boot:
  bluefin-cli-init.service → sysupdate pulls tar.zst → importctl import-tar
  → /var/lib/machines/homebrew/ (btrfs subvolume) → machinectl enable+start

Runtime:
  brew install <pkg> → /usr/bin/brew (wrapper) → systemd-run --machine=homebrew
  → runs as linuxbrew user inside container
```

Container image is built separately in `projectbluefin/fsdk-containers` and published to GitHub Releases. It is NOT built from source inside this repo.

## Failure modes

### `PrivateUsers=pick` breaks bind-mount ownership

`PrivateUsers=pick` uses a dynamic UID offset. Host-owned `/home/linuxbrew` appears as `nobody/nogroup` inside the container because the host UID does not map. `PrivateUsersOwnership=auto` only rechowns container-internal files, NOT bind mounts. The current fix is `PrivateUsers=no` — this means container root equals host root (not a security boundary for Tier 1).

### `@mount` in SystemCallFilter breaks Homebrew 6

Homebrew 6 uses bubblewrap for formula sandboxing. bwrap requires `clone3`, `mount`, `pivot_root`, `open_tree`, `move_mount`, `unshare`. Adding `@mount` to the deny list silently breaks `brew install` for any source-built formula. The nspawn config intentionally omits `@mount` from its deny list.

### sysupdate component mismatch

The transfer config lives at `/usr/lib/sysupdate.bluefin-cli.d/` (note the component suffix). Running `systemd-sysupdate --component=bluefin-cli update` matches this path. Installing the file to `/usr/lib/sysupdate.d/` instead would make it invisible to the component-scoped update.

### Sysupdate requires a companion `SHA256SUMS` file

`homebrew-container.transfer` uses the `url-file` source type against GitHub Releases, which does not generate a `SHA256SUMS` manifest automatically. It must be produced and uploaded alongside the tarball in CI, or `systemd-sysupdate` verification fails.

### Import must follow the sysupdate pull

`systemd-sysupdate --component=bluefin-cli update` only downloads and stages the new release; `importctl import-tar` is what swaps `/var/lib/machines/homebrew` to the new subvolume. Both `ExecStart=` lines in `bluefin-cli-init.service` must run in order — skipping the import leaves the old container image active.

## Verification

```bash
# Element parses cleanly
just bst show bluefin/bluefin-cli.bst

# nspawn config does NOT use PrivateUsers=pick
grep "PrivateUsers" files/bluefin-cli/homebrew.nspawn

# SystemCallFilter does NOT deny @mount
grep "SystemCallFilter" files/bluefin-cli/homebrew.nspawn
```

## Related skills

- [buildstream](../buildstream/SKILL.md) — BST element syntax
- [oci-layers](../oci-layers/SKILL.md) — how this element reaches the final image
- [ujust-recipes](../ujust-recipes/SKILL.md) — `ujust setup-bluefin-cli` and related recipes
