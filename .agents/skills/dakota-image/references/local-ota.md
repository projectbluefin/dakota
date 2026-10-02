---

name: local-ota
description: Conditional bootc upgrade evidence for an independently provisioned VM or hardware target; not a supported Dakota boot or OTA entrypoint.
metadata:
  context7-sources:
    - /bootc-dev/bootc
---

# Conditional Bootc OTA Verification

Dakota's current supported lab verification surface is its container GNOME GUI.
This reference applies only when a bootable candidate and an independently
provisioned bootc VM or hardware target already exist. It is not a Dakota
installer/boot recipe, and container QA does not demonstrate this path.

## When to Use

Use when explicitly validating upgrades on that separate bootc target. Read the
[canonical Ghost Lab procedure](../SKILL.md#ghost-lab-procedure) for every BST
operation; local registry work does not authorize local builds or checkout.

## When NOT to Use

- CI pipeline questions → load `dakota-ci`

## Core Process

1. Start a local registry.
2. Obtain the exact-SHA candidate from Ghost Lab and copy its published OCI image to the target registry without invoking workstation BST.
3. Point a VM or hardware target at the registry.
4. Run `bootc upgrade` and reboot.
5. Verify the upgraded system actually reaches the expected graphical state.

## Overview

Use an existing registry-accessible candidate → configure the separate bootc target → stage an upgrade → reboot → verify the active digest and changed runtime behavior.

## Setup

### Start Local Registry

Start the registry explicitly; the repository has no `registry-start` recipe.

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

## Candidate → Target → Verification

Build and artifact operations follow the [Ghost Lab procedure](../SKILL.md#ghost-lab-procedure).
Copy the published candidate to the target-accessible registry with OCI tooling,
preserving its content, and record source and destination digests. Use a unique
candidate tag rather than replacing a shared channel. The target's image source
must resolve to the intended candidate, not the image already booted.

On the independently provisioned target, use `bootc switch` to select its
registry image source, then reboot. For subsequent updates to that source, run
`bootc upgrade` and reboot. Both operations stage the deployment; successful
staging alone is not proof of a working upgrade. See the
[official bootc upgrade guidance](https://bootc.dev/bootc/bootc-upgrades.7.html).

Full OTA evidence requires the target's pre-upgrade digest, staged candidate,
reboot, active candidate digest, and changed runtime behavior. If no separately
provisioned bootc target is available, report OTA as unverified.

## After Reboot

```bash
bootc status                     # confirm new image is active
systemctl --failed               # check for failed units
journalctl -p err --since boot   # check for boot errors
```

## Reverting to GHCR

```bash
sudo bootc switch ghcr.io/projectbluefin/dakota:stable
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
| "Container QA passed, so OTA works." | Container GUI and transactional upgrades are separate surfaces. |
| "A bootable target must exist because these instructions exist." | This reference requires an independently provisioned target; it does not supply one. |
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

## Known Failure Modes & Invariants

### zstd:chunked Incompatibility with bootc composefs

Do not use `--compression-format=zstd:chunked` for local registry pushes. It breaks `bootc switch` and `bootc upgrade` when the image uses composefs.

Use OCI copy/push tooling without `--compression-format=zstd:chunked`; this
transfer step must not invoke a local BST-backed export or `push-local` recipe.

### bootc switch Same-Content Trap

`bootc switch <tag>` silently does nothing if the tag resolves to the already-booted digest. Force the upgrade with the exact digest:

```bash
DIGEST=$(curl -sI http://<zot-registry>/v2/dakota/manifests/<TAG> \
  -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
  | grep -i docker-content-digest | awk '{print $2}' | tr -d '\r')
sudo bootc switch --transport registry <zot-registry>/dakota@${DIGEST}
```

### Functional Assertions Over File Presence

File existence alone does not prove an integration works. Use a non-mutating
behavior check on the test machine, for example:

```bash
# Checks that the installed CLI loads and returns its version.
flatpak --version | grep -q '^Flatpak '

# Checks that the installed, merged ujust recipe set parses.
ujust --list
```

These checks do not prove Flatpak installation or a particular recipe's behavior.
For a changed recipe, identify its definition in Dakota or the pinned common
source and design a safe assertion for that behavior. Do not invoke `ujust report`
or another data-donation command as an unattended smoke test; those commands
require a user's review and consent.
