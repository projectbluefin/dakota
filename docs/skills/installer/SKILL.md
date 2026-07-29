---
name: installer
description: Dakota's bootc install defaults and the boundary between the deployed OCI image, the installer Flatpak (bootc-installer), and the ISO (dakota-iso). Load when changing install-time behavior or debugging firstboot state on a freshly installed system.
---

# Installer

## Overview

Dakota ships bootc install configuration (`files/bootc-install/00-defaults.toml`) that controls how `bootc install to-disk` partitions and installs the image. The installer GUI (`projectbluefin/bootc-installer`) and the ISO (`projectbluefin/dakota-iso`) are separate repositories. Changes that affect what lands on the **installed system** belong here; changes to the install UX or ISO boot flow do not.

## When to use

- Changing bootc install defaults (bootloader, filesystem type, partition layout).
- Debugging a CI boot-check failure related to disk provisioning.
- Tracing the boundary between what Dakota owns vs. what `bootc-installer` or `dakota-iso` owns.
- Investigating firstboot state on an installed system.

## When not to use

- Modifying the installer GTK UI or fisherman backend → work in `projectbluefin/bootc-installer`.
- Changing ISO creation or live-boot behavior → work in `projectbluefin/dakota-iso`.
- Adding packages to the image → [add-package](../add-package/SKILL.md).

## Authoritative sources

- `files/bootc-install/00-defaults.toml` — install-time defaults shipped inside the image
- `elements/bluefin/bootc-install-config.bst` — BST element that installs the TOML file
- `scripts/check_publish_workflow.py` — CI validator that enforces boot-check invariants against the publish workflow and the defaults file

## Workflow

1. **Identify which repo owns the change.** Use the boundary table below.
2. **Edit `files/bootc-install/00-defaults.toml`** if changing install defaults.
3. **Run `python3 scripts/check_publish_workflow.py`** to validate that the defaults file and the publish workflow remain consistent.
4. **Push and verify CI boot-check passes** — the publish workflow runs `bootc install to-disk` against the built image.

### Repository boundary

| Concern | Owner |
|---------|-------|
| OCI image content deployed to disk | `projectbluefin/dakota` (this repo) |
| bootc install defaults (bootloader, fs type) | `projectbluefin/dakota` — `files/bootc-install/` |
| Installer GTK4 GUI + fisherman Go backend | `projectbluefin/bootc-installer` |
| ISO creation, live squashfs, installer Flatpak bundling | `projectbluefin/dakota-iso` |

### Load-bearing defaults

The current `00-defaults.toml` sets:

- `bootloader = "systemd"` — systemd-boot, not GRUB.
- `[install.filesystem.root] type = "xfs"` — required since bootc no longer defaults a root filesystem type.

Both are enforced by `scripts/check_publish_workflow.py`. The CI boot-check itself passes its own `--filesystem ext4 --bootloader none` flags and does not read these defaults, so removing either does not break the boot-check directly.

## Failure modes

### Missing root filesystem type

If `type = "xfs"` is removed from the defaults, `scripts/check_publish_workflow.py` fails validation (`just validate`), because it requires the defaults file to set `type = "xfs"` independent of what the CI boot-check overrides. The real consequence is on **hardware installs that use the shipped defaults**: `bootc install to-disk` exits 1 with "No root filesystem specified" and the disk remains unpartitioned, since bootc no longer defaults a root filesystem type.

### Installer Flatpak leaking to installed system

The ISO installs the bootc-installer as a system Flatpak. When `bootc install` copies the filesystem, the installer Flatpak may appear on the target. A firstboot oneshot service removes it. If that service is missing or broken, users see the installer as an available app post-install.

## Verification

```bash
# Defaults file is internally consistent with the publish workflow
python3 scripts/check_publish_workflow.py

# Element installs the file to the correct path
just bst show bluefin/bootc-install-config.bst
```

## Related skills

- [oci-layers](../oci-layers/SKILL.md) — how the install-config element reaches the final image
- [e2e-ci](../e2e-ci/SKILL.md) — CI boot-check that validates the install flow
