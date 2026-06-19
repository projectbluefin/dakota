---

name: local-ota
description: Tests bootc upgrades via a local zot registry — QEMU VM or physical hardware. Covers registry setup, insecure registry configuration, and the build-push-upgrade loop. Load when validating image changes without pushing to GHCR.
metadata:
  context7-sources:
    - /bootc-dev/bootc
---

# Local & Hardware OTA Testing

Load when testing bootc upgrades via a local registry — QEMU VM or physical hardware.

## When to Use

Use when you need to validate a Dakota image upgrade locally before GHCR publish, reproduce bootc upgrade behavior on hardware, or test a boot path with a local registry.

## When NOT to Use

- CI pipeline questions → `ci.md`

## Core Process

1. Start a local registry.
2. Build and push the image to that registry.
3. Point a VM or hardware target at the registry.
4. Run `bootc upgrade` and reboot.
5. Verify the upgraded system actually reaches the expected graphical state.

## Overview

Run a local zot registry → build dakota image → push to local registry → boot a VM or physical machine pointed at the local registry → run `bootc upgrade`.

## Setup

### Start Local Registry

```bash
# Idempotent — safe to run multiple times
just registry-start
```

Manual fallback:
```bash
sudo podman run -d --name egg-registry --replace \
  -p 5000:5000 \
  -v egg-registry-data:/var/lib/registry \
  ghcr.io/project-zot/zot-minimal-linux-amd64:latest
```

The `egg-registry-data` volume persists across reboots. Verify it's bound to `0.0.0.0:5000` (not just localhost):
```bash
sudo podman inspect egg-registry | grep -i hostip
```

### Configure Insecure Registry on Test Machine

**QEMU VM** — inside the VM, `10.0.2.2` is the QEMU user-mode gateway (your host machine):
```bash
sudo tee /etc/containers/registries.conf.d/50-local-dev.conf <<'EOF'
[[registry]]
location = "10.0.2.2:5000"
insecure = true
EOF
```

**Physical hardware** — use your build host's LAN IP:
```bash
sudo tee /etc/containers/registries.conf.d/50-lab-dev.conf <<'EOF'
[[registry]]
location = "<build-host-ip>:5000"
insecure = true
EOF
```

This drop-in persists across reboots. Leave it in place — it's harmless when the machine points at GHCR.

## Build → Push → Test Loop

```bash
# 1. Build the image
just build

# 2. Export OCI image to podman
just export

# 3. Push to local registry
just push-local localhost:5000          # QEMU path (host gateway = 10.0.2.2 from inside VM)
just push-local <build-host-ip>:5000   # Physical hardware path

# 4a. QEMU VM — boot a VM
just boot-fast     # ephemeral VM via virtiofs (requires virtiofsd)
just boot-vm       # standard QEMU VM with display

# 5. On the test machine — switch to local registry (first time only)
sudo bootc switch 10.0.2.2:5000/dakota:latest          # QEMU
sudo bootc switch <build-host-ip>:5000/dakota:latest   # Physical

# 6. Subsequent upgrades
sudo bootc upgrade
sudo systemctl reboot
```

**Lab rule:** Build host alone is not a lab result. Full loop = build → push → `bootc switch` on test machine → reboot → verify.

## After Reboot

```bash
bootc status                     # confirm new image is active
systemctl --failed               # check for failed units
journalctl -p err --since boot   # check for boot errors
```

## Reverting to GHCR

```bash
sudo bootc switch ghcr.io/projectbluefin/dakota:latest
sudo systemctl reboot
```

## Port Conflict Fix

If port 5000 is occupied:
```bash
sudo ss -tlnp | grep 5000
sudo podman start egg-registry
```

---

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "CI passed, so I don't need local OTA." | This repo explicitly values real upgrade evidence. |
| "A local registry is too much setup for one test." | It's cheaper than shipping a broken upgrade path. |
| "Booted once" means success. | Success is upgrade + reboot + expected runtime state. |

## Red Flags

- Testing image contents without exercising `bootc upgrade`
- Declaring success without a reboot
- Using local host state as proof instead of a VM/hardware target
- Skipping registry wiring and testing a different path than users take

## Verification

- [ ] Image was pushed to the local registry actually used by the target
- [ ] `bootc upgrade` ran against that registry
- [ ] The target rebooted successfully
- [ ] Post-upgrade runtime state was checked, not assumed

## Lessons Learned

### zstd:chunked broken with bootc composefs

Do not use `--compression-format=zstd:chunked` for local registry pushes. It breaks `bootc switch`/`bootc upgrade` when the image uses composefs.

```bash
# Correct
just push-local localhost:5000

# Wrong — breaks composefs
sudo podman push --compression-format=zstd:chunked localhost:5000/dakota:latest
```

### bootc switch same-content trap

`bootc switch <tag>` silently does nothing if the tag resolves to the already-booted digest. Force the upgrade with the exact digest:

```bash
DIGEST=$(curl -sI http://<zot-registry>/v2/dakota/manifests/<TAG> \
  -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
  | grep -i docker-content-digest | awk '{print $2}' | tr -d '\r')
sudo bootc switch --transport registry <zot-registry>/dakota@${DIGEST}
```

### Assertions must execute — not just check file presence

`test -f /path/to/file` is not a functional test. Any recipe must be tested by executing it and checking output:

```bash
# BAD — only confirms the file exists
--assert 'installed:test -f /usr/share/ublue-os/just/default.just'

# GOOD — confirms the recipe actually runs
--assert 'recipe-runs:echo n | TERM=dumb ujust report 2>&1 | grep -qiE "Collecting"'
```

### BST failure cache trap

When BST caches a failed build, retrying without clearing the cache immediately fails again with `[00:00:00]` elapsed.

```bash
just bst artifact delete bluefin/myelement.bst
just bst build bluefin/myelement.bst
```

### Pre-existing failures vs your changes

Before attributing a build failure to your branch, confirm the same element fails on `upstream/main`:

```bash
git stash
git checkout upstream/main
just bst build bluefin/<failing-element>.bst
git checkout -
git stash pop
```

If it fails on upstream too, file an issue immediately and continue.

### just 1.47.1 heredoc tokenizer

just 1.47.1 aggressively tokenizes heredoc content in shebang recipes, rejecting lines starting with `-`, `...`, `$(uname -m)` with flags past column 25, or `(1/5/15 min)`.

**Fix:** Replace heredocs with `printf '%s\n'` per line and pre-compute command substitutions into variables.

### ujust vs just distinction

- `just` = developer build system (`Justfile` in repo root)
- `ujust` = user-facing commands in the running image (`files/just-overrides/default.just`)

Changes to `files/just-overrides/default.just` require a BST element rebuild to land in the image.
