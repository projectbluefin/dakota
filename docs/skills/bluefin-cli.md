# bluefin-cli skill

Operational knowledge for the Bluefin CLI developer container — a ChromeOS-style
systemd-nspawn container that ships Homebrew as an immutable OS component.

## What it is

A versioned, signed container rootfs (ubuntu 24.04 + systemd + Homebrew) shipped
alongside the Dakota OCI image. The container runs as a persistent system machine
(`machinectl`), and the host `brew` wrapper transparently proxies commands into it.

Users see zero difference. `brew install gh` works. Packages live in `/home/linuxbrew`
on the host, persisting across container image updates.

## File map

```
elements/bluefin/bluefin-cli.bst           BST element — ships all config/service files
files/bluefin-cli/
  homebrew.nspawn                          nspawn container config (hardened defaults)
  bluefin-cli-init.service                 First-boot systemd service (pulls + imports container)
  homebrew-container.transfer              systemd-sysupdate transfer config
  brew                                     Host wrapper script (bash; Rust binary planned)
files/just-overrides/bluefin-cli.just      ujust recipes
docs/skills/bluefin-cli.md                 This file
```

Container image built by: `projectbluefin/fsdk-containers` (separate repo, separate agent).
Container image published to: `https://github.com/projectbluefin/bluefin-cli/releases/`

## Architecture

```
OCI image (dakota)
└─ /etc/systemd/nspawn/homebrew.nspawn    — container config
└─ /usr/lib/systemd/system/
       bluefin-cli-init.service           — first-boot init
└─ /usr/lib/sysupdate.d/
       homebrew-container.transfer        — update config
└─ /usr/bin/brew                          — host wrapper

First boot:
  bluefin-cli-init.service
    → systemd-sysupdate pulls homebrew-env-<ver>.tar.zst (SHA256+cosign verified)
    → importctl import-tar → /var/lib/machines/homebrew/ (btrfs subvolume)
    → machinectl enable + start homebrew

Runtime:
  $ brew install cowsay
    → /usr/bin/brew (wrapper)
      → systemd-run --machine=homebrew --uid=linuxbrew
        → /home/linuxbrew/.linuxbrew/bin/brew install cowsay

Updates:
  systemd-sysupdate.timer pulls new container tarballs weekly
  ujust update-bluefin-cli — manual update + restart
  /home/linuxbrew/ bind-mounted from host — packages always preserved
```

## Critical nspawn gotchas

**PrivateUsers must be `no` for dev containers.** Default `PrivateUsers=pick` uses a
dynamic UID offset (e.g., base 378273792). Bind-mounted dirs like `/home/linuxbrew`
show as `nobody/nogroup` inside the container because the host UID doesn't map.
`PrivateUsersOwnership=auto` only rechowns container image files, NOT bind mounts.
Solution: `PrivateUsers=no` in `homebrew.nspawn`.

**`ResolvConf=bind-host` is the right directive.** Not `BindReadOnly=/etc/resolv.conf`.
Context7-confirmed; this is a first-class nspawn directive.

**Container needs real systemd init.** The `homebrew/brew` Docker image has no init
process and fails with `machinectl start`. Use a proper ubuntu + systemd base.

## Wrapper performance

Current bash wrapper: ~50-100ms overhead (dbus `StartTransientUnit` round-trip).

Planned Rust wrapper (nsenter path, ~3ms):
1. Varlink query `io.systemd.Machine` socket → get leader PID of homebrew machine
2. `nsenter --pid --mount --uts --ipc -t <leader-pid>`
3. `su linuxbrew -c brew "$@"`

Socket: `/run/systemd/machine/io.systemd.Machine` (systemd 254+, confirmed on Bluefin).

## Security tiers

Same container image, different config at install time.

| Tier | Mechanism | Overhead | Use case |
|------|-----------|----------|----------|
| 1 — hardened nspawn | namespace + cap drop + syscall filter | ~35MB RAM | Default daily use |
| 2 — Cloud Hypervisor + kata-kernel | KVM hypervisor boundary | ~55MB RAM + ~125ms boot | Untrusted tools / agents |

Tier 1 is NOT a hard security boundary (shares kernel). Tier 2 is a genuine
hypervisor boundary — equivalent to macOS VMs, stronger VMM security story
(Rust + Landlock vs QEMU C codebase).

For the VM tier:
- VMM: Cloud Hypervisor (Rust, Intel/Microsoft, virtiofs DAX)
- Kernel: kata-kernel from `kata-containers` package (standalone; no Kata runtime)
- virtiofsd shares `/home/linuxbrew` as DAX — ~95% native I/O via shared memory
- Cloud Hypervisor process itself is Landlock-sandboxed (can only see brew prefix + kernel)

## btrfs integration

`importctl import-tar` automatically creates a btrfs subvolume on btrfs hosts.
The subvolume is atomically swapped on update (old version retained for rollback).

Snapper should exclude `/var/lib/machines` to avoid snapshotting the entire container.
Add to Snapper config: `SUBVOLUME_FILTER="/var/lib/machines"`

## What gets removed from dakota deps.bst when this ships

| Element | Reason |
|---------|--------|
| `bluefin/brew.bst` | Replaced by container |
| `bluefin/brew-tarball.bst` | Replaced by container |
| `bluefin/tealdeer.bst` | Duplicate — already in cli.Brewfile |
| `bluefin/zig.bst` | Dev tool — goes in container |
| `bluefin/distrobox.bst` | Largely superseded |
| `freedesktop-sdk.bst:components/buildstream2.bst` | Dev-only, large |
| `freedesktop-sdk.bst:components/flatpak-builder.bst` | Dev-only |
| `freedesktop-sdk.bst:components/git-lfs.bst` | Dev use only |
| `freedesktop-sdk.bst:components/debuginfod.bst` | Dev/debug only |
| `gnome-build-meta.bst:gnomeos-deps/bpftop.bst` | Dev observability |

These are NOT removed yet — this element is a placeholder. The `deps.bst` changes
happen in a separate PR after the container image is published and tested.

## Open questions (as of 2026-06-25)

1. distrobox: keep as escape hatch or remove?
2. `smartmontools`/`tcpdump` need `CAP_NET_RAW` — host packages or work around in container?
3. First-boot timing: container init happens at `multi-user.target` — does this race with GNOME session start on first login?
4. `machinectl enable` writes a symlink under `/etc/systemd/system/` — does this survive bootc A/B? It should, since `/etc` is the mutable layer.
5. Per-user brew instances? Current design assumes shared `/home/linuxbrew`. systemd-homed creates user home on login — needs testing with homed integration.

## Lessons learned

**2026-06-25 — Container image can't be BST-built in-tree easily.** The Homebrew
bootstrap process requires network access (downloads Ruby portable) and does not fit
in a BST `kind: manual` element (no network in BST sandbox). Correct approach: build
container via Containerfile in `projectbluefin/fsdk-containers`, publish as signed tar
to GitHub Releases, pull at first boot via systemd-sysupdate.

**2026-06-25 — `PrivateUsers=no` is correct for bind-mount compatibility but wrong for security.**
`PrivateUsers=no` → container root == host root. A container escape is immediately a
host-root event. This is the pragmatic choice for Tier 1 dev ergonomics, but is NOT
a security boundary. The real fix: `PrivateUsers=pick` + **idmapped mounts** for
`/home/linuxbrew` (kernel 5.12+). `PrivateUsersOwnership=auto` only rechowns
container-internal files, NOT bind mounts. This remains an open architecture problem.

**2026-06-25 — `SystemCallFilter=~@mount` BREAKS Homebrew 6 bubblewrap.**
Homebrew 6 on Linux uses bubblewrap for formula sandboxing. bwrap requires `clone3`,
`mount`, `pivot_root`, `open_tree`, `move_mount`, `unshare`. Adding `@mount` to the
deny list silently breaks `brew install` for any non-bottle formula. Only deny
`@reboot @swap @obsolete`. Validate with: `brew install hello` (source build).

**2026-06-25 — virtiofs DAX `cache=always` is wrong for the mutable Homebrew prefix.**
Known truncation/page-fault pathologies and stale coherency bugs for writable data.
For writable `/home/linuxbrew`: use non-DAX virtiofs (default). Reserve DAX only for
read-only immutable content.

**2026-06-25 — Raw `nsenter` bypasses cgroup/SELinux containment.**
`setns()` moves namespaces but NOT cgroup membership or LSM labels. Fast wrapper
design: use AF_UNIX exec agent inside the container (resident daemon, SO_PEERCRED
auth, one connect + one fork/exec per command). Do not ship naked nsenter.

**2026-06-25 — btrfs CoW hurts hot-write Homebrew dirs.**
`chattr +C` (NOCOW) on: `HOMEBREW_CACHE`, `HOMEBREW_TEMP`, brew lock dirs.
Put these on a separate btrfs subvolume. Keep CoW on Cellar for snapshots.

**2026-06-25 — systemd-sysupdate needs SHA256SUMS alongside tarballs.** The `url-tar`
source type requires a `SHA256SUMS` file at the same path prefix. GitHub Releases
does not generate this automatically — must be produced and uploaded in CI.

**2026-06-25 — `ResolvConf=bind-host` is the right directive.** Not `BindReadOnly=/etc/resolv.conf`.
Context7-confirmed; this is a first-class nspawn directive.

**2026-06-25 — Container needs real systemd init.** The `homebrew/brew` Docker image has no init
process and fails with `machinectl start`. Use a proper ubuntu + systemd base.
