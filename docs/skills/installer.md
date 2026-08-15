---

name: installer
description: bootc-installer (GTK4/Adwaita Flatpak) for Dakota. Covers two-component architecture (Python GUI + Go fisherman backend), dev setup, demo mode, and the dakota/dakota-iso boundary. Use when working on installer UI, the Flatpak recipe, fisherman integration, or firstboot installer-cleanup behavior.
metadata:
  context7-sources:
    - /bootc-dev/bootc
---

# Installer (bootc-installer)

Load when working on the Bluefin Dakota installer or debugging ISO installer integration.

## When to Use

Use when working on `projectbluefin/bootc-installer`, the Dakota ISO installer path, firstboot cleanup, or the boundary between the desktop image and the installer experience.

## When NOT to Use

- General Dakota package/image work unrelated to install flows
- CI-only release pipeline debugging → CI skills
- BST element authoring unrelated to installer behavior

## Core Process

1. Confirm whether the change belongs in `bootc-installer`, `dakota`, or `dakota-iso`.
2. Respect the two-component split: Python GTK frontend vs Go backend.
3. Preserve the repo boundary; do not hide installer policy inside the wrong repo.
4. Validate demo mode / firstboot cleanup / integration points explicitly.

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

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It's all installer behavior, so I can fix it in any repo." | Wrong boundary decisions are how installer bugs become factory bugs. |
| "The GUI and backend are basically one thing." | They fail differently and must be debugged that way. |
| "A firstboot cleanup tweak is harmless." | Those are exactly the changes that strand bad state on installed systems. |

## Red Flags

- Mixing Dakota image policy with installer UI concerns
- Changing firstboot cleanup without tracing its full lifecycle
- Debugging the GTK frontend when the bug is clearly in fisherman/backend behavior
- Treating ISO integration as if it were normal desktop runtime behavior

## Verification

- [ ] The change was made in the correct repo/layer
- [ ] Frontend/backend ownership is clear
- [ ] Firstboot/install cleanup behavior was explicitly considered
- [ ] The integration path with Dakota or dakota-iso is still clear to future agents

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`

### Installer flatpak leaks to installed system (2026-06-01)

The ISO's `install-flatpaks.sh` installs the bootc-installer as a system Flatpak into `/var/lib/flatpak/`. When fisherman runs `bootc install`, it copies all system flatpaks to the target — including the installer itself. The installed system then shows the installer as an available app.

**Fix:** `bluefin-remove-installer.service` (a firstboot oneshot in `files/firstboot/`) removes `org.bootcinstaller.Installer` and `.Devel` if present, then prunes unused runtimes. Gated by a stamp file at `/var/lib/ublue-os/.installer-removed`.

**Root cause is in `dakota-iso`** (`install-flatpaks.sh`), but the defensive fix lives in dakota because the installed image should never ship the installer regardless of how it got there.

### Fisherman e2e coverage gaps tracked in dakota (2026-08-11)

Fisherman (`tuna-os/fisherman`, the installer's Go backend) e2e coverage gaps
are tracked as [dakota#651](https://github.com/projectbluefin/dakota/issues/651)
even though the source fixes land upstream — Dakota still owns verifying the
*installed* system. Three post-boot assertions (installer Flatpak exclusion,
`efibootmgr` UEFI entry presence, `rd.luks.uuid=`/`rd.luks.name=` cmdline
parsing) are implemented in the testsuite `installer` suite, not Dakota's own
generic-image boot-check. See `docs/skills/e2e-ci.md` → "Installer Post-Boot
Assertions (fisherman)" for the current status of each assertion and the
sequencing rule.

As of this writing, two of the three assertions can report real signal
against a fisherman-installed target; the LUKS cmdline assertion cannot yet
because it inherited a dead `LUKS_ENABLED` env-var gate that nothing sets —
see the linked table for the fix in flight upstream in
`projectbluefin/testsuite`. Don't read a green `installer` suite run as proof
all three assertions executed without checking that table first.

## Dakota vs Dakota-ISO boundary

The installer is NOT built from source in this repo. The boundary:

| What | Where |
|------|-------|
| OCI image (deployed to disk) | `projectbluefin/dakota` — this repo |
| Live ISO, installer Flatpak, squashfs | `projectbluefin/dakota-iso` |
| Installer source (GTK4 app) | `projectbluefin/bootc-installer` |
| Installer backend (Go) | `tuna-os/fisherman` (submodule in bootc-installer) |

If a bug involves the installer UI, recipe, or ISO boot — it's a `dakota-iso` or `bootc-installer` issue. If it involves what's on the installed system after installation — it's a `dakota` issue (fix in elements or firstboot services).
