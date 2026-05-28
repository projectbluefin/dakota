# Local OTA Testing with QEMU

Load when testing bootc upgrades via a local registry without physical hardware. Uses a local zot registry and QEMU VM instead of the hardware test lab.

## When NOT to Use

- Testing on physical hardware → `testlab.md`
- Setting up the hardware lab for the first time → `testlab-setup.md`
- CI pipeline questions → `ci.md`

## Overview

Run a local zot registry → build dakota image → push to local registry → boot a QEMU VM pointed at the local registry → run `bootc upgrade` inside the VM.

## Setup

### Start Local Registry

```bash
# Start a local zot registry (listening on port 5000)
sudo podman run -d --name egg-registry --replace \
  -p 5000:5000 \
  -v egg-registry-data:/var/lib/registry \
  ghcr.io/project-zot/zot-minimal-linux-amd64:latest

# Verify it's running
sudo podman ps | grep egg-registry
```

The registry stores data in the `egg-registry-data` volume and persists across reboots.

### Configure Insecure Registry (VM)

Inside the QEMU VM, configure it to pull from the local registry:
```bash
sudo mkdir -p /etc/containers/registries.conf.d
sudo tee /etc/containers/registries.conf.d/50-local-dev.conf <<'EOF'
[[registry]]
location = "10.0.2.2:5000"
insecure = true
EOF
```

`10.0.2.2` is the QEMU user-mode gateway — this is your host machine's localhost from inside the VM.

## Build → Publish → Test Loop

```bash
# 1. Build the image
just build

# 2. Export OCI image to podman
just export

# 3. Push to local registry
sudo podman push localhost:5000/dakota:latest

# 4. Boot a VM (choose one):
just boot-fast     # ephemeral VM via virtiofs (requires virtiofsd)
just boot-vm       # standard QEMU VM with display

# 5. Inside the VM — switch to local registry (first time; use 10.0.2.2 = QEMU host gateway)
sudo bootc switch 10.0.2.2:5000/dakota:latest

# 6. Subsequent upgrades
sudo bootc upgrade
sudo systemctl reboot
```

Note: `boot-fast` / `boot-vm` boot the local exported image directly. For testing the registry pull path, `sudo bootc switch` inside the VM must point to the host registry at `10.0.2.2:5000` (QEMU gateway).

## After Reboot

Verify inside the VM:
```bash
bootc status                     # confirm new image is active
systemctl --failed               # check for failed units
journalctl -p err --since boot   # check for boot errors
```

## Port Conflict Fix

If `localhost:5000` is occupied:
```bash
sudo ss -tlnp | grep 5000   # find PID
sudo kill <PID>
sudo podman start egg-registry
```

## Reverting to GHCR

When done testing locally:
```bash
# Inside VM
sudo bootc switch ghcr.io/projectbluefin/dakota:latest
sudo systemctl reboot
```

## zstd:chunked Warning

Do not use `podman push` with `--compression-format=zstd:chunked` for bootc images. The zstd:chunked format is broken with bootc's composefs backend. Use plain `podman push`:

```bash
# ✅ Correct
sudo podman push localhost:5000/dakota:latest

# ❌ Wrong — breaks composefs
sudo podman push --compression-format=zstd:chunked localhost:5000/dakota:latest
```

## Lessons Learned

### zstd:chunked broken with bootc composefs

Using `--compression-format=zstd:chunked` with `podman push` to a local registry breaks `bootc switch`/`bootc upgrade` when the image uses composefs. Always use plain `podman push` for local testing.

> Add further entries here when you discover a new pattern.
> Format: `### <pattern name> (YYYY-MM-DD)`
