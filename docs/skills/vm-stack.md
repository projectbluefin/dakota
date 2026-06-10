# VM Stack (virt-manager + QEMU flatpaks)

## Overview

The full VM stack is delivered by two system flatpaks — no brew packages, no BST image changes, no RPMs. These flatpaks are completely self-contained and managed by Flathub updates.

| Flatpak | What it provides |
|---|---|
| `org.virt_manager.virt-manager` | libvirtd, virtqemud, virsh, virt-install, virt-clone, SPICE client, USB redirect, ISO tools |
| `org.virt_manager.virt_manager.Extension.Qemu` | QEMU 9.x (x86_64/aarch64/arm/i386), swtpm + swtpm_setup, edk2 UEFI firmware for all arches |

## User session capability matrix

| Feature | Works in user session? |
|---|---|
| Linux VMs | Yes |
| Windows 11 (UEFI + TPM + Secure Boot) | Yes — edk2-x86_64-secure-code.fd + swtpm bundled in extension |
| USB passthrough | Yes — usbredirect bundled, `devices=all` flatpak permission |
| SPICE display, clipboard, audio | Yes |
| SPICE shared folders | Yes — spice-webdavd bundled |
| Internet access from VMs | Yes — slirp/user-mode networking built into QEMU |
| /dev/kvm acceleration | Yes — `devices=all` flatpak permission |
| aarch64/arm VMs | Yes |
| Bridged networking (VM on LAN) | No — needs root libvirtd |
| virtiofsd shared folders | No — not bundled |
| 3D acceleration in VMs | No — no virglrenderer |
| PCI/VFIO passthrough | No — needs root |

System mode (`qemu:///system`) requires a root libvirtd daemon. Brew as a system service is a non-starter on an immutable image. System mode is the DX image's job.

## ujust recipes

```
ujust setup-vms     # install flatpaks + configure user session (no confirm, idempotent)
ujust toggle-vms    # detect state, confirm, install or remove
```

`toggle-vms` is also offered as a `gum confirm` during `ujust toggle-devmode` when enabling DX mode.

## The only config needed

The bundled `libvirt.conf` defaults imply `qemu:///system` (no system daemon → "no connections" screen). One line fixes it:

```bash
mkdir -p ~/.config/libvirt
echo 'uri_default = "qemu:///session"' >> ~/.config/libvirt/libvirt.conf
```

`setup-vms` handles this automatically and is idempotent.

## Critical: system flatpaks only — never --user

All flatpaks in bluefin/dakota are installed system-wide. This is non-negotiable:

```bash
# correct
flatpak install --system --noninteractive flathub org.virt_manager.virt-manager

# WRONG — never do this in a ujust recipe
flatpak install --user ...
```

The canonical image-level mechanism is `brew bundle --file=...Brewfile` with `flatpak "app.id"` entries (see `system-dx-flatpaks.Brewfile` in `projectbluefin/common`). The recipe uses `flatpak install --system` directly because it's opt-in and not a default image flatpak.

`flatpak install --system` works as a normal user — polkit handles privilege escalation internally. No `pkexec` wrapper needed.

`flatpak override --system` requires root. We avoid it entirely here — the virt-manager manifest already declares `xdg-run/libvirt` and `devices=all`, so no override is needed.

## Lessons Learned

### The QEMU extension must be explicitly installed (2026-06-09)

`flatpak install org.virt_manager.virt-manager` does NOT automatically pull `org.virt_manager.virt_manager.Extension.Qemu`. It must be listed explicitly. Without the extension, virt-manager has no QEMU binaries, swtpm, or UEFI firmware and cannot create VMs.

### virt-manager flatpak bundles its own libvirtd (2026-06-09)

The flatpak ships `libvirtd`, `virtqemud`, `virsh`, and the full libvirt driver suite internally. No host-level libvirt installation is needed for user session. brew libvirt is only relevant if you want a host-level system daemon for system session (bridged networking etc.) — and brew as a system service is a non-starter on immutable images.

### USB passthrough works in user session (2026-06-09)

`usbredirect` and `libusbredirhost` are bundled in the virt-manager flatpak. The flatpak manifest has `devices=all` which includes `/dev/bus/usb`. USB passthrough via SPICE USB redirection works without system mode.

### flatpak override --system requires root; flatpak install --system does not (2026-06-09)

`flatpak install --system` triggers polkit elevation internally — works as a normal user.
`flatpak override --system` writes to `/var/lib/flatpak/overrides/` directly — requires root.
For this VM stack, no override is needed, so the privilege question is moot.
