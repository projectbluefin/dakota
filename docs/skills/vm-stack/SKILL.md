---
name: vm-stack
description: Flatpak-delivered virt-manager/QEMU virtualization stack and its user-session boundaries. Load when deciding whether a VM feature belongs in the Dakota image, in the Flatpak stack, or is out of scope for the user-session model.
---

# VM Stack

## Overview

Dakota's full virtualization capability is delivered by two system Flatpaks from Flathub — not by BST elements, not by brew, and not by image packages. The stack runs entirely in user session (`qemu:///session`) by default, which means certain root-only features (bridged networking, VFIO passthrough) are architecturally out of scope.

## When to use

- Answering whether a VM feature is supported in Dakota.
- Deciding whether a virtualization change belongs in the image or in the Flatpak stack.
- Debugging user-session VM limitations vs. root-only capabilities.

## When not to use

- CI boot-check or testsuite QEMU wiring → [e2e-ci](../e2e-ci/SKILL.md)
- Adding packages to the Dakota image → [add-package](../add-package/SKILL.md)

## Authoritative sources

- Flathub manifests for `org.virt_manager.virt-manager` and `org.virt_manager.virt_manager.Extension.Qemu`
- `ujust` recipes (if present in `files/just-overrides/`) — check with `grep -r "virt\|vm" files/just-overrides/`

## Workflow

1. **Determine scope**: is the feature user-session or root-only? See the matrix below.
2. **If Flatpak-owned**: no Dakota image change needed. The Flatpak stack is self-contained.
3. **If image-owned** (e.g. a kernel module, udev rule, or polkit policy): route to [add-package](../add-package/SKILL.md).
4. **If root-only**: document the limitation; do not add workarounds that break the immutable-image model.

### User-session capability matrix

| Feature | User session? | Notes |
|---------|:---:|-------|
| Linux/Windows VMs (UEFI+TPM) | ✅ | edk2 + swtpm bundled in QEMU extension |
| USB passthrough (SPICE redirect) | ✅ | `devices=all` flatpak permission |
| SPICE display, clipboard, audio | ✅ | |
| /dev/kvm acceleration | ✅ | |
| aarch64/arm emulation | ✅ | |
| Bridged networking (VM on LAN) | ❌ | Requires root libvirtd |
| PCI/VFIO passthrough | ❌ | Requires root |
| virtiofsd shared folders | ❌ | Not bundled |
| 3D GPU acceleration in VMs | ❌ | No virglrenderer |

### Key operational facts

- The QEMU extension (`org.virt_manager.virt_manager.Extension.Qemu`) must be installed explicitly — it is not pulled automatically with virt-manager.
- The virt-manager Flatpak bundles its own `libvirtd` / `virtqemud` — no host libvirt installation needed for user session.
- `flatpak install --system` works as a normal user (polkit handles elevation). `flatpak override --system` requires root but is not needed here.
- User-session default requires `uri_default = "qemu:///session"` in `~/.config/libvirt/libvirt.conf`.

## Failure modes

### Extension missing — "cannot create VM"

If only the base `org.virt_manager.virt-manager` is installed without the QEMU extension, virt-manager has no hypervisor binaries and cannot create any VM. The fix is to install the extension explicitly.

### Default URI points to system session

Without `uri_default = "qemu:///session"` in user config, virt-manager attempts `qemu:///system` which requires a host-level libvirtd daemon. On an immutable image without that daemon, the result is a "no connections" error.

## Verification

```bash
# Both flatpaks installed
flatpak list --system | grep -i virt

# User session works
virsh -c qemu:///session list --all
```

## Related skills

- [ujust-recipes](../ujust-recipes/SKILL.md) — recipes that may install/configure the VM stack
- [e2e-ci](../e2e-ci/SKILL.md) — CI QEMU usage (different from user VM stack)
