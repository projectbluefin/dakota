# Implementation Plan: Add Curated GNOME Extensions to Dakota

Tracked from epic: `projectbluefin/common#1087`

## Global Constraints
- Follow Dakota packaging rules (`.agents/skills/dakota-packaging`): package software as BuildStream elements; no RPMs, DNF, or post-build overlays.
- Pinned sources with reproducible refs / SHA256 checksums; deterministic builds with no network access in sandbox.
- Extensions must be compatible with GNOME 50 (verified for all 7 extensions).
- Schema files for extensions that have settings in gschema overrides must be installed both in the extension directory and in `%{install-root}%{datadir}/glib-2.0/schemas/` so `glib-compile-schemas` succeeds during image composition.
- Syncthing quicksettings pill and menu header must be renamed from "Syncthing" to "Sync Folder".
- All 7 extensions enabled in `[org.gnome.shell] enabled-extensions` list in `elements/bluefin/shell-extensions/disable-ext-validator.bst`.
- Override settings configured in `disable-ext-validator.bst`:
  - `Bluetooth-Battery-Meter`: `level-indicator-color = 0` (Symbolic)
  - `syncthing-toggle`: `start-stop-only = true`

---

## Task 1: Add EGO alias and package GNOME extension elements

### Objective
Define the alias in `include/aliases.yml` and create the BuildStream element files under `elements/bluefin/shell-extensions/` for all 7 extensions:
1. `elements/bluefin/shell-extensions/bluetooth-battery-meter.bst` (UUID: `Bluetooth-Battery-Meter@maniacx.github.com`)
2. `elements/bluefin/shell-extensions/syncthing-toggle.bst` (UUID: `syncthing-toggle@rehhouari.github.com`, pill and menu header renamed to "Sync Folder")
3. `elements/bluefin/shell-extensions/tilingshell.bst` (UUID: `tilingshell@ferrarodomenico.com`)
4. `elements/bluefin/shell-extensions/tailscale-qs.bst` (UUID: `tailscale-gnome-qs@tailscale-qs.github.io`)
5. `elements/bluefin/shell-extensions/copyous.bst` (UUID: `copyous@boerdereinar.dev`)
6. `elements/bluefin/shell-extensions/quicksettings-audio-devices-hider.bst` (UUID: `quicksettings-audio-devices-hider@marcinjahn.com`)
7. `elements/bluefin/shell-extensions/quicksettings-audio-devices-renamer.bst` (UUID: `quicksettings-audio-devices-renamer@marcinjahn.com`)

### Implementation Details
1. In `include/aliases.yml`, add alias:
   ```yaml
   gnome_extensions: https://extensions.gnome.org/download-extension/
   ```
2. Create each `.bst` file under `elements/bluefin/shell-extensions/`:
   - `bluetooth-battery-meter.bst`:
     - source: `github:maniacx/Bluetooth-Battery-Meter.git` at commit `1862ef79b69756aee2297bd15a6ae6656b7c11ab` (branch `GNOME46`).
     - compiles po files into mo files, compiles schemas in extension dir, installs schema to `glib-2.0/schemas`.
   - `syncthing-toggle.bst`:
     - source: `github:rehhouari/gnome-shell-extension-syncthing-toggle.git` at commit `658424caf8238b57b11e0e373aff92a7c41ecb7c` (branch `main`).
     - patches `toggle.js` with `sed -i "s/_('Syncthing')/_('Sync Folder')/g" toggle.js` to rename pill and menu header.
     - compiles schemas in extension dir, installs schema to `glib-2.0/schemas`.
   - `tilingshell.bst`:
     - source: `kind: zip`, url `github_files:domferr/tilingshell/releases/download/17.3/tilingshell%40ferrarodomenico.com.zip`, ref `63ab8230b62c1a888d5af40e47aef0676e5e99ac367e35f51a797fe3b9a79370`.
     - installs files, compiles schemas in extension dir, installs schema to `glib-2.0/schemas`.
   - `tailscale-qs.bst`:
     - source: `github:tailscale-qs/tailscale-gnome-qs.git` at commit `7feced3f4b9bdf3ae775b203ca023ffbca2b29cb` (tag `v9`).
     - copies from `tailscale-gnome-qs@tailscale-qs.github.io`.
   - `copyous.bst`:
     - source: `kind: zip`, url `github_files:boerdereinar/copyous/releases/download/v2.0.1/copyous%40boerdereinar.dev.zip`, ref `7c2bfdecd66b78dc1f2491ae74e16216fca7190307411de21966da9fd47d4141`.
     - compiles schemas in extension dir, installs schema to `glib-2.0/schemas`.
   - `quicksettings-audio-devices-hider.bst`:
     - source: `kind: zip`, url `gnome_extensions:quicksettings-audio-devices-hider@marcinjahn.com.shell-extension.zip?version_tag=69924`, ref `217082e049572ae54bc90bc09240f896e25f4a2609e0c0aa4b7133bed46d935d`.
     - installs files, compiles schemas in extension dir, installs schema to `glib-2.0/schemas`.
   - `quicksettings-audio-devices-renamer.bst`:
     - source: `kind: zip`, url `gnome_extensions:quicksettings-audio-devices-renamer@marcinjahn.com.shell-extension.zip?version_tag=69925`, ref `a4f33897983376a23c5de69d6a008d1451afcc05cd7ce3b56630bd739c095a2e`.
     - installs files, compiles schemas in extension dir, installs schema to `glib-2.0/schemas`.

---

## Task 2: Integrate into gnome-shell-extensions and configure enablement overrides

### Objective
Wire the new elements into `elements/bluefin/gnome-shell-extensions.bst` and configure `elements/bluefin/shell-extensions/disable-ext-validator.bst` with the full enabled extensions list and requested settings.

### Implementation Details
1. Edit `elements/bluefin/gnome-shell-extensions.bst`:
   Add to `depends:`:
   - `bluefin/shell-extensions/bluetooth-battery-meter.bst`
   - `bluefin/shell-extensions/syncthing-toggle.bst`
   - `bluefin/shell-extensions/tilingshell.bst`
   - `bluefin/shell-extensions/tailscale-qs.bst`
   - `bluefin/shell-extensions/copyous.bst`
   - `bluefin/shell-extensions/quicksettings-audio-devices-hider.bst`
   - `bluefin/shell-extensions/quicksettings-audio-devices-renamer.bst`

2. Edit `elements/bluefin/shell-extensions/disable-ext-validator.bst`:
   Update the gschema override `zz3-bluefin-unsupported-stuff.gschema.override`:
   - `enabled-extensions` must include:
     - `'caffeine@patapon.info'`
     - `'appindicatorsupport@rgcjonas.gmail.com'`
     - `'bazaar-integration@kolunmi.github.io'`
     - `'blur-my-shell@aunetx'`
     - `'dash-to-dock@micxgx.gmail.com'`
     - `'gradia-integration@alexandervanhee.github.io'`
     - `'gsconnect@andyholmes.github.io'`
     - `'custom-command-list@storageb.github.com'`
     - `'Bluetooth-Battery-Meter@maniacx.github.com'`
     - `'copyous@boerdereinar.dev'`
     - `'quicksettings-audio-devices-hider@marcinjahn.com'`
     - `'quicksettings-audio-devices-renamer@marcinjahn.com'`
     - `'syncthing-toggle@rehhouari.github.com'`
     - `'tilingshell@ferrarodomenico.com'`
     - `'tailscale-gnome-qs@tailscale-qs.github.io'`
   - Add section:
     ```ini
     [org.gnome.shell.extensions.Bluetooth-Battery-Meter]
     level-indicator-color=0

     [org.gnome.shell.extensions.syncthing-toggle]
     start-stop-only=true
     ```

---

## Task 3: Validate configuration and test suites

### Objective
Run repository validation checks and tests to verify that manifests parse cleanly, unit tests pass, and publish workflows are consistent.

### Implementation Details
1. Run `just check-publish-workflow`.
2. Run `just test-render-card`.
3. Verify that all 7 element files exist and are referenced in `elements/bluefin/gnome-shell-extensions.bst`.
