# Dakota Overview

Load when you need context on what dakota is, how it differs from production Bluefin, what unique features it has, or when planning new package additions.

## When NOT to Use

- Authoring `.bst` element files → use `buildstream.md` or `add-package.md`
- Debugging CI pipeline failures → use `ci.md`
- Looking up specific packaging patterns → use the relevant `packaging-*.md` skill

## Hard Facts — Violations Recorded 3+ Times

**Dakota runtime is composefs. It is NOT OSTree.**
- The BST export includes `/sysroot/` artifacts (OSTree build leftovers) — `--prune /sysroot/` strips them at rechunking time.
- The booted system uses the composefs-oci backend. There is no ostree runtime on a running dakota system.
- Never suggest OSTree-specific tooling (bootupd, ostree admin, rpm-ostree) for a running dakota system.

**zstd:chunked is disabled. Plain podman push is correct.**
- zstd:chunked fails with bootc composefs ("unexpected EOF reading tar entry") regardless of flags.
- After chunkah rechunking (`chunkah build → podman load`), plain `podman push` is the correct path.
- Do not reintroduce skopeo, `--compression-format=zstd:chunked`, or any oci-dir workaround for post-chunkah pushes. Read issue projectbluefin/dakota#119 before asserting anything about push compression.

**Hardware confirmation is required before upstream PRs.**
- The validation gate is: `bootc upgrade` on test hardware succeeds + reboot + GDM active.
- CI green is not sufficient. Hardware confirmation is.

**Production image = `ghcr.io/projectbluefin/dakota:stable`.**
- Streams: `:testing` (nightly, e2e-gated), `:latest` + `:stable` (weekly promotion)
- When someone says "is X in the image", check the GHCR image via `skopeo inspect` or `podman run --rm` — not a local machine unless explicitly asked.

**Verify hypothesis before stating root cause.**
- State missing packages as a hypothesis ("likely cause is X") until confirmed by live evidence.

## What Is Dakota?

Dakota is Project Bluefin's **CoreOS-model bootc image** — built entirely from source using **BuildStream 2**. It follows the same architecture as CoreOS and GNOME OS: bootc-native, composefs runtime, no OSTree, no rpm-ostree, no dnf.

freedesktop-sdk provides glibc/systemd/kernel, gnome-build-meta provides GNOME Shell/Mutter/GTK, and dakota adds Bluefin-specific packages on top.

**Key positioning:** Dakota is a **curated subset** of production Bluefin, not a 1:1 clone. It intentionally includes things production Bluefin doesn't have (sudo-rs, uutils-coreutils, GNOME nightly) and intentionally omits things that don't make sense for a from-source build (Nvidia drivers, ZFS, enterprise AD/Kerberos).

Published image: `ghcr.io/projectbluefin/dakota:{testing,latest,stable}`

## Architecture Comparison

| Dimension | **Dakota** | **bluefin** | **bluefin-lts** |
|---|---|---|---|
| **Base** | freedesktop-sdk + gnome-build-meta (from source) | Fedora Silverblue (pre-built RPMs) | CentOS Stream 10 (pre-built RPMs) |
| **Build system** | BuildStream 2 (hermetic sandbox builds) | Containerfile + `dnf install` | Containerfile + `dnf install` |
| **Desktop** | GNOME (nightly/latest) | GNOME (Fedora's version) | GNOME 48 (pinned) |
| **Kernel** | freedesktop-sdk kernel | Fedora kernel + akmods | CentOS kernel + akmods |
| **Update model** | `bootc` (native) | `rpm-ostree` (migrating to bootc) | `bootc` (native) |
| **Package count** | ~20 Bluefin-specific elements | ~80 base + ~60 DX RPMs | ~80 base + DX/GDX RPMs |
| **Architectures** | x86_64, aarch64, riscv64 | x86_64 primarily | x86_64, aarch64 |

### Fundamental Difference

Production Bluefin images are **Containerfile-based overlays** — they start with `FROM base_image` and run `dnf install`. Dakota **builds the entire stack from source** using BuildStream. With good cache hits from upstream CAS, most is pre-built. But Bluefin-specific Rust packages (bootc, uutils-coreutils, sudo-rs) and GRUB are compiled from source.

## What Dakota Has That Others Don't

| Feature | Notes |
|---|---|
| **sudo-rs** (Rust sudo) | Memory-safe sudo replacement |
| **uutils-coreutils** (Rust coreutils) | Memory-safe coreutils |
| **Built entirely from source** | Reproducible, auditable, no RPM dependency |
| **GNOME nightly** | Latest GNOME, ahead of Fedora |
| **riscv64 support** | Neither bluefin nor bluefin-lts supports this |

## Gap Analysis

Gaps as of 2026-06-03. Y = present, N = absent.

### Shell & Terminal Tools

| Package | Dakota | bluefin |
|---|:---:|:---:|
| just | Y | Y |
| wl-clipboard | Y | Y |
| glow | Y | Y |
| gum | Y | Y |
| fzf | Y | Y |
| fish | N | Y |
| zsh | N | Y |
| tmux | N | Y |
| fastfetch | N | Y |
| Starship prompt | N | Y |

### Networking & VPN

| Package | Dakota | bluefin |
|---|:---:|:---:|
| Tailscale | Y | Y |
| wireguard-tools | N | Y |

### Containers

| Package | Dakota | bluefin |
|---|:---:|:---:|
| podman | Y | Y |
| skopeo | Y | Y |
| distrobox | Y | N |

### Hardware & Drivers (Intentionally Out of Scope)

Nvidia drivers, ZFS, Xbox controller (xone), Framework laptop modules — not in scope. Building these from source is not practical.

### Notable Gaps (Priority Order)

| Package | Dakota | Notes |
|---|:---:|---|
| fastfetch | N | System info tool, in both production Bluefins |
| Starship prompt | N | Shell prompt, core Bluefin UX; pre-built binary |
| fish shell | N | Alternative shell; requires build from source |
| fwupd | Y | via gnome-build-meta junction |
| uupd (auto-updater) | Y | `elements/bluefin/uupd.bst` |
| Bazaar (app store) | N | Flatpak-based app store |

## Build Optimization Notes

Heavy build contributors:

1. **Rust packages** — bootc (~200 crates), uutils-coreutils (~250 crates), sudo-rs. These are the crown jewels of dakota's approach — keep building from source.
2. **GRUB** — built in 3 variants (i386-pc, i386-efi, x86_64-efi). Required because upstream GNOME OS uses systemd-boot only; Bluefin needs GRUB for bootc compatibility.
3. **Junction patches** — patches to freedesktop-sdk and gnome-build-meta modify junction identity hashes, which may affect upstream cache hit rates. Upstreaming patches would improve this.
4. **Pre-built binary pattern** — used for Tailscale, Zig, Homebrew, Go CLI tools. New packages should follow this pattern where possible.

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
