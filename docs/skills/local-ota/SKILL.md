---
name: local-ota
description: Local and hardware OTA testing via a zot registry. Load when validating bootc upgrades locally, testing image changes without pushing to GHCR, or reproducing upgrade behavior on physical hardware.
---

# Local & Hardware OTA Testing

## Overview

Build a Dakota image, push it to a local zot registry, then run `bootc upgrade` on a QEMU VM or physical machine to verify the upgrade path end-to-end. This carries real safety consequences on hardware — every rollback step matters.

## When to use

- Validating image changes before GHCR publish
- Reproducing bootc upgrade/switch behavior on real hardware
- Testing the full boot path with a local registry

## When not to use

- CI-level image validation (handled by `just validate` and the e2e workflow)

## Authoritative sources

- `Justfile` recipes: `push-local`, `boot-fast`, `boot-vm`, `boot-test`, `export`
- `files/just-overrides/default.just` — user-facing `ujust` commands available inside the image
- bootc upstream documentation for `bootc switch` / `bootc upgrade` behavior

## Workflow

1. **Build and export the image:**
   ```bash
   just build
   just export
   ```

2. **Push to local zot registry:**
   ```bash
   just push-local localhost:5000          # QEMU (host gateway = 10.0.2.2 from inside VM)
   just push-local <build-host-ip>:5000   # physical hardware
   ```

3. **Configure insecure registry on the test machine** (one-time):
   - QEMU VM — `10.0.2.2` is the host gateway:
     ```bash
     sudo tee /etc/containers/registries.conf.d/50-local-dev.conf <<'EOF'
     [[registry]]
     location = "10.0.2.2:5000"
     insecure = true
     EOF
     ```
   - Physical hardware — use the build host's LAN IP in the `location` field.

4. **Switch to the local image (first time only):**
   ```bash
   sudo bootc switch 10.0.2.2:5000/dakota:latest      # QEMU
   sudo bootc switch <build-host-ip>:5000/dakota:latest  # physical
   ```

5. **Subsequent upgrades:**
   ```bash
   sudo bootc upgrade
   sudo systemctl reboot
   ```

6. **Verify after reboot:**
   ```bash
   bootc status
   systemctl --failed
   journalctl -p err --since boot
   ```

7. **Revert to GHCR when done:**
   ```bash
   sudo bootc switch ghcr.io/projectbluefin/dakota:latest
   sudo systemctl reboot
   ```

## Failure modes

- **`zstd:chunked` breaks composefs**: never use `--compression-format=zstd:chunked` with local pushes. Use `just push-local` which avoids this.
- **`bootc switch` same-digest no-op**: if the tag resolves to the already-booted digest, `bootc switch` silently does nothing. Force the switch with the exact manifest digest.
- **BST failure cache**: a cached failed build retries instantly with `[00:00:00]` elapsed. Clear it first: `just bst artifact delete bluefin/<element>.bst`.
- **Port 5000 conflict**: verify with `sudo ss -tlnp | grep 5000` and ensure the zot container is running.

## Verification

- Image was pushed to the registry the target machine actually uses
- `bootc upgrade` ran against that registry
- The target rebooted successfully
- Post-reboot state was checked (`bootc status`, `systemctl --failed`)

## Related skills

- [buildstream](../buildstream/SKILL.md)
- [e2e-ci](../e2e-ci/SKILL.md)
- [vm-stack](../vm-stack/SKILL.md)
