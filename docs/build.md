# Build reference

## Requirements

| Tool | Why | Install |
|---|---|---|
| `argo` and `kubectl` | Submit and monitor Ghost Lab workflows | Configure access to the lab's `argo` namespace |
| `just` | Repository non-BST checks and lab recipes | Pre-installed on Bluefin |
| Ghost Lab access | All BST operations and candidate container GUI verification | Lab Argo workflows; no workstation BST |

## Repo layout

| Path | Purpose |
|---|---|
| `elements/freedesktop-sdk.bst` | fdsdk junction — pinned to a release tag |
| `elements/gnome-build-meta.bst` | GBM junction — tracks `gnome-51` branch |
| `elements/bluefin/` | Bluefin-specific elements (~40 elements) |
| `elements/oci/` | OCI image assembly — layers + final image |
| `patches/linux/` | Kernel patches (via fdsdk linux element) |
| `files/` | Static files installed by elements |
| `.agents/skills/` | Agent skills — discovered and loaded on demand |
| `Justfile` | Repository recipes — local use is limited to non-BST checks |

## Dev loop

All BuildStream operations run on **Ghost Lab**, including graph `show`, the
BST portion of validation, shells, and artifact checkout. The workstation is
the Argo/kubectl client, not a BST build host.

Follow the canonical [Ghost Lab procedure in `dakota-image`](../.agents/skills/dakota-image/SKILL.md#ghost-lab-procedure)
for exact-SHA submission, isolated candidate tags, artifact inspection, and
candidate GUI verification. Read the deployed WorkflowTemplate inputs before
submitting; the lab procedure is the single source of truth for this flow.

These non-BST checks may run locally:

```bash
just check-publish-workflow
just test-render-card
```

`just validate` also invokes BST, so its graph portion belongs on the lab.
The current Dakota runtime verification surface is the lab's container GNOME
GUI. It does not establish VM/hardware boot or OTA support or success.


## Desktop integrations

Keep the established desktop defaults, with fuzzy application search, Tiling
Shell, and BudsLink enabled. BudsLink's default panel stays hidden until a
supported device is present. Syncthing Toggle, Tailscale Quick Settings, the
extra audio panel/hider/renamer, and Power Status Color are installed but
opt-in through the Extensions app. Their required backends
remain available; enabling a control should not require installing missing
native software.

- **Rounded blur:** `bluefin/gnome-rounded-blur.bst` is a runtime dependency of
  Blur My Shell. It builds the pinned upstream source against the same Mutter
  as GNOME Shell, with a downstream [GNOME 51 port](https://github.com/kancko/gnome-rounded-blur/pull/7).
  All Mutter dependencies require ABI 51 and versions `>= 51.0, < 52.0`; review
  the source pin and patch together with every GNOME major-version junction bump.
  There is no automatic source tracking or cross-ABI fallback.
  [Upstream](https://github.com/kancko/gnome-rounded-blur/blob/f3bfcc796e1214c1e1d4287ee35cb132ad8133f0/src/meson.build)
  installs `libblur-effect-1.0.so.1` and `Blur-1.0.typelib` under the SDK's
  architecture-specific library directory—not `libgnome-rounded-blur.so` or
  Fedora's `/usr/lib64`. The compose drops development files, not the versioned
  library or typelib. Blur My Shell imports `gi://Blur`; a loose `.so` alone
  does not satisfy that contract.
  `files/dconf/08-dakota-extension-defaults` enables popup blur through the
  distro database because the extension bundles its own schemas. Users can
  disable it; their saved settings are not rewritten or locked. If removing the
  library, revert this popup default in the same change.
  Verify in the changed image's active GNOME session with Blur My Shell enabled:
  set `GSETTINGS_SCHEMA_DIR=/usr/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas`
  when using `/usr/bin/gsettings`; `org.gnome.shell.extensions.blur-my-shell`
  `rounded-blur-found` and `org.gnome.shell.extensions.blur-my-shell.popup`
  `blur` must both be `true`. Check Quick Settings, the calendar, and volume and
  brightness OSDs visually, plus the Shell journal for loader errors. File
  presence, a successful import, or an old image's settings are not rendering
  evidence. Use the [Ghost Lab procedure](../.agents/skills/dakota-image/SKILL.md#ghost-lab-procedure)
  for the candidate build, artifact inspection, and graphical checks.
- **Sync Folder (Syncthing):** `bluefin/syncthing.bst` builds the vendored source
  release, with CGO SQLite support and self-updates disabled. A private
  `core/syncthing-go.bst` build dependency supplies the required Go 1.26 compiler
  without replacing the image's toolchain. The Syncthing element installs the
  standard `syncthing.service` user unit. Once enabled, its Quick Settings toggle starts and
  stops that unit, waits for systemd jobs, and refreshes service state. Open its
  Web GUI to pair devices and choose folders. Syncthing is not started for every
  user automatically; identities are generated at runtime, never in the image.
- **Tailscale:** the daemon is enabled in the image, but a fresh installation is
  unauthenticated. The application launcher offers **Tailscale Setup**, as does
  the Quick Settings menu after the user enables that extension. Setup requests administrator
  approval to make the requesting account a
  [Tailscale operator](https://tailscale.com/docs/reference/troubleshooting/linux/linux-operator-permission),
  then opens browser sign-in. It will not replace another user's operator
  assignment. No auth keys, tailnet identity, exit-node selection, or automatic
  privilege grants are baked into the image. Closing setup does not disconnect
  an existing connection or revoke an already-approved operator assignment.
- **BudsLink:** the companion Flatpak is declared in the image's preinstall
  configuration. `flatpak-preinstall.service` checks `flatpak preinstall --help`
  before invoking installation. The extension activates the app's D-Bus service
  when supported earbuds connect, and retries if installation finishes after
  login. Installation needs network access; pairing remains the user's choice.

Syncthing and Tailscale are independent controls. There is no automatic tailnet
folder sharing: Syncthing devices and folders require explicit pairing/sharing.

Existing users' saved extension selections are not rewritten. There is no
login migration to force new extensions on or turn off extensions a user has
selected. Image defaults apply when there is no user override. For host
diagnosis use `/usr/bin/gsettings`, not a Homebrew copy that may lack the dconf
backend and therefore report schema defaults instead of the running desktop's
settings.

Tiling Shell uses the GNOME Extensions reviewed archive that declares GNOME 50
support. Its package build checks that metadata, rather than treating disabled
Shell version validation as proof of compatibility. Packaging checks do not
replace a graphical-session test, particularly when multiple audio extensions
modify the same Quick Settings controls.

## Fastfetch ownership

`bluefin/common.bst` installs the fastfetch config and wrapper from its pinned
`projectbluefin/common` source. Do not copy the layout into Dakota or snapshot
its icons/colors in tests. Common updates should carry presentation changes
without a second sync step.

The temporary `patches/common/0001-fastfetch-install-date.patch` changes only
the date command to read the first-boot record. Drop it when common supports
that record through a shared helper. `firstboot-date.bst` owns the runtime
records, not the presentation; `nerd-fonts-symbols.bst` supplies icon fallback
without changing the default text font. The existing booted-image helper patch
in `common.bst` is separate and remains until common supports that record too.

Exercise `bluefin/common.bst` against the pinned source in a Ghost Lab build
workload. A source rewrite that invalidates the patch must be reviewed, not
worked around by restoring a local config. Check glyph rendering in the
candidate's active container GUI session.
The common source import also does not supply `fastfetch-user-count` or
`bazaar-install-count`; those weekly-statistics inputs remain a separate parity
gap, not a reason to fork the config or invent counts.

## Ghostty theme and configuration defaults

`bluefin/common.bst` imports Ghostty's GNOME profile from `projectbluefin/common`.
Because Dakota uses Ghostty as its primary terminal emulator:
- `patches/common/0002-ghostty-dual-theme.patch` configures `theme = light:Catppuccin Latte,dark:Catppuccin Mocha`
  so that Ghostty follows the GNOME Dark/Light style toggle button out of the box.
  Drop this patch once common carries dual-theme by default.
- `patches/ghostty/0001-disable-resize-overlay-by-default.patch` sets the compiled-in
  default for `resize-overlay` to `never` in `elements/bluefin/ghostty.bst`. This ensures
  both existing and new user sessions avoid the Wayland resize feedback loop with
  GNOME Shell/Mutter without relying solely on `/etc/skel` propagation.

## What NOT to do

| Don't | Why |
|---|---|
| `rpm-ostree`, `pip install`, `apt-get` in elements | BST-only build; all deps from junctions |
| `$(date)`, `$(hostname)`, `$(curl ...)` in `install-commands` | Breaks reproducibility and BST caching |
| Patch junction files directly | Use `patch_queue` source in the junction `.bst` |
| Force-push to `main` | Stable promotion operates on image digests from testing SHAs, not Git branch updates |
| Close issues via API or comment | Use `Closes #NNN` in the PR body |
| Open a PR without graph validation on Ghost Lab | Local `just validate` invokes BST and is not the supported path |
