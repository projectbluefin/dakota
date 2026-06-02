# Installer (bootc-installer)

Load when working on the Bluefin Dakota installer or debugging ISO installer integration.

## What It Is

A GTK4/Adwaita Flatpak installer for Project Bluefin Dakota — a soft fork of `tuna-os/tuna-installer`.

- **Canonical repo:** `projectbluefin/bootc-installer`
- **Default branch:** `dev` (active work); `prod` (stable, triggers Flatpak release CI)
- **App ID:** `org.bootcinstaller.Installer`

## Architecture

```text
bootc-installer/
├── bootc_installer/         # Python GTK4/Adwaita GUI
│   ├── defaults/            # Wizard step widgets (disk, encryption, user, welcome)
│   ├── views/               # Progress, done, confirm screens
│   ├── windows/             # Main window + dialogs
│   ├── gtk/                 # Blueprint UI files (.blp)
│   └── utils/               # Builder, Processor, RecipeLoader
├── fisherman/               # Git submodule → tuna-os/fisherman (Go backend)
│   ├── fisherman/cmd/       # main.go — 9-step install pipeline
│   └── data/images.json     # Image catalog (bundled in GResource)
├── flatpak/                 # Flatpak manifests
├── recipe.json              # Dakota-specific recipe (distro_name, steps, imgref)
└── run-dev.sh               # Local dev launcher
```

**Two-component model:** Python GUI collects wizard input → Processor builds fisherman recipe JSON → fisherman (Go) runs as root via pkexec and does the actual disk install.

## Dev Setup

```bash
# Init fisherman submodule
cd bootc-installer
git submodule update --init --recursive

# Build fisherman
mkdir -p /var/tmp/gobuild
cd fisherman/fisherman && go build -o /var/tmp/fisherman-test ./cmd/fisherman/

# Install Python build deps (example — adjust for your distro)
sudo dnf install -y \
  meson ninja-build python3-gobject python3-devel \
  blueprint-compiler libadwaita-devel desktop-file-utils mutter

# Build + install
meson setup build --prefix=/tmp/bootc-installer-dev -Dvariant=gnome -Dbuild-fisherman=false
ninja -C build
meson install -C build
```

## Dev Loop

```bash
./run-dev.sh          # build if changed, launch in BOOTC_DEMO mode
./run-dev.sh --rebuild  # force full rebuild
./run-dev.sh --logs   # tail debug log only
```

**`BOOTC_DEMO=1`** — clicking Install runs a 5-second fake progress sequence (9 steps). No fisherman launched, no disk touched. Set by default in `run-dev.sh`.

**Debug log:** `~/.cache/tuna-installer/installer-debug.log`  
**Run log:** `/tmp/bootc-installer-run.log`

## Key Customizations vs. Upstream

- Image picker step removed (Dakota only, imgref in recipe.json)
- Welcome screen customized for Bluefin
- Default hostname: `dakota`
- Encryption copy: plain-language phrasing
- Passphrase strength feedback (weak/fair/strong)
- Done screen: `"{name} is installed"` + restart prompt
- `BOOTC_DEMO=1` demo mode — full UI walkthrough, no disk touched

## Integration with Dakota ISO

The installer is bundled in the Dakota ISO via `elements/oci/bluefin.bst`. When working on ISO integration:

1. Build the installer Flatpak (`prod` branch triggers CI release)
2. Update the Flatpak ref in the relevant dakota element
3. Full image build + `just boot-vm` to test the installer flow

## Upstream

Upstream: `tuna-os/tuna-installer` (read-only, pull upstream fixes).

To pull upstream changes:
```bash
git remote add upstream https://github.com/tuna-os/tuna-installer
git fetch upstream
git merge upstream/main  # or cherry-pick relevant commits
```

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`

### Installer flatpak leaks to installed system (2026-06-01)

The ISO's `install-flatpaks.sh` installs the bootc-installer as a system Flatpak into `/var/lib/flatpak/`. When fisherman runs `bootc install`, it copies all system flatpaks to the target — including the installer itself. The installed system then shows the installer as an available app.

**Fix:** `bluefin-remove-installer.service` (a firstboot oneshot in `files/firstboot/`) removes `org.bootcinstaller.Installer` and `.Devel` if present, then prunes unused runtimes. Gated by a stamp file at `/var/lib/ublue-os/.installer-removed`.

**Root cause is in `dakota-iso`** (`install-flatpaks.sh`), but the defensive fix lives in dakota because the installed image should never ship the installer regardless of how it got there.

## Dakota vs Dakota-ISO boundary

The installer is NOT built from source in this repo. The boundary:

| What | Where |
|------|-------|
| OCI image (deployed to disk) | `projectbluefin/dakota` — this repo |
| Live ISO, installer Flatpak, squashfs | `projectbluefin/dakota-iso` |
| Installer source (GTK4 app) | `projectbluefin/bootc-installer` |
| Installer backend (Go) | `tuna-os/fisherman` (submodule in bootc-installer) |

If a bug involves the installer UI, recipe, or ISO boot — it's a `dakota-iso` or `bootc-installer` issue. If it involves what's on the installed system after installation — it's a `dakota` issue (fix in elements or firstboot services).
