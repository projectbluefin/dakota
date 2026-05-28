# Testlab — One-Time Setup

Load this only when setting up hardware for the first time. For the active dev loop, use `testlab.md` instead.

## When to Use

- Setting up a fresh test machine to pull from your build host's local registry
- Re-provisioning your build host after a reinstall
- Configuring insecure registry access between build host and test machine

## Prerequisites

| Requirement | Why |
|---|---|
| Build host with `just`, `podman`, and the dakota repo | Builds and publishes the image |
| Test machine running dakota (or any bootc-based image) | Hardware validation target |
| Network connectivity between the two machines | Registry pull from test machine to build host |

## Test Machine Setup (One-Time per Fresh Disk)

### 1. Allow insecure registry from build host

On the test machine:
```bash
sudo tee /etc/containers/registries.conf.d/50-lab-dev.conf <<'EOF'
[[registry]]
location = "<build-host-ip>:5000"
insecure = true
EOF
```

This drop-in persists across reboots. Leave it in place — it is harmless when the test machine points at GHCR.

### 2. Switch from GHCR to your build host's registry

```bash
sudo bootc switch <build-host-ip>:5000/dakota:latest
```

After this, `sudo bootc upgrade` pulls from your build host's zot registry. The test machine stays pointed here until explicitly switched back.

### 3. Revert to upstream GHCR

```bash
sudo bootc switch ghcr.io/projectbluefin/dakota:latest
sudo systemctl reboot
```

The `50-lab-dev.conf` drop-in does not need to be removed.

## Build Host Setup

### Start the Registry

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

The `egg-registry-data` volume persists across reboots.

### Port 5000 Conflict Fix

```bash
sudo ss -tlnp | grep 5000   # find PID
sudo kill <PID>
sudo podman start egg-registry
```

Verify the registry is bound to `0.0.0.0:5000` (not just localhost):
```bash
sudo podman inspect egg-registry | grep -i hostip
```

## VM Testing — Full Disk Install Path

For composefs validation or full install testing via QEMU:

```bash
just generate-bootable-image   # bootc install to-disk
just boot-vm                   # requires display; use boot-fast for headless
```

**Headless QEMU** (when no display is attached):
```bash
DISK=$(realpath bootable.raw)
qemu-system-x86_64 \
    -enable-kvm -m 4096 -cpu host -smp 2 \
    -drive file="${DISK}",format=raw,if=virtio \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.fd \
    -drive if=pflash,format=raw,file=.ovmf-vars.fd \
    -display none \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
    -chardev stdio,id=char0,mux=on,signal=off \
    -serial chardev:char0 -mon chardev=char0
```

Inside the QEMU VM (to access build host's registry via QEMU NAT):
- Build host localhost = `10.0.2.2` from inside the VM
- Configure insecure registry: `location = "10.0.2.2:5000"`

**`bootc install to-disk` must run from inside the container** (via `just bootc install ...`).
Do NOT run `--source-imgref` from outside the container.
Do NOT use `--bootloader auto` — dakota uses systemd-boot; bootupd is RPM-specific and not present.

## Cross-References

| Skill | When |
|---|---|
| `testlab.md` | Active build/publish/bootc upgrade loop |
| `local-ota.md` | QEMU VM variant — no physical hardware needed |
| `ci.md` | GHCR publish pipeline, what happens after local validation |

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
