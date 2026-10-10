# Build reference

## Requirements

| Tool | Why | Install |
|---|---|---|
| `podman` (rootful + rootless) | BST container + export/boot | Pre-installed on Bluefin |
| `just` | All build/test commands | Pre-installed on Bluefin |
| `qemu` | VM boot | `brew install qemu` |
| `virtiofsd` | `just boot-fast` only | Host package manager / `brew install virtiofsd` |
| `bcvk` | Ephemeral VM from container | Auto-installed by `just boot-fast` via cargo |
| ~100 GB disk, ~16 GB RAM | BST cache + parallel builds | — |

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
| `Justfile` | All local dev commands — run `just --list` first |

## Dev loop

```bash
just validate                  # graph check — always run first (~5 min, no build)

just build default             # build default image — warm cache: 2–5 min; cold: 60–90 min
# or: just build all           # build all variants (default + nvidia)

just lint                      # bootc container lint — must pass before PR

just boot-test                 # automated smoke test — exits 0 on success
just boot-fast                 # interactive ephemeral VM via virtiofs (requires virtiofsd)

just show-me-the-future        # full loop: build → export → disk image → QEMU VM
```

First run is slow (cold BST cache). Subsequent runs are fast — BST caches by content hash.

## Useful BST commands

```bash
just validate                                        # check element graph
just bst build bluefin/tailscale.bst                 # build one element
just bst shell --build bluefin/tailscale.bst         # sandbox shell
just bst show --deps all oci/bluefin.bst             # full dependency graph
```

## Updating source pins

Run the same source-update logic as CI from a feature branch with a clean working
tree (based on `upstream/testing` for normal development):

```bash
just update-sources --list                  # preview the scope, no network or writes
just update-sources                         # CI-managed sources, kernels, and core junctions
just update-sources --group bundle          # everything except core junctions
just update-sources --group core-junctions  # GNOME Build Meta + matching SDK + patches
just update-sources --group kernels         # standard + OGC kernel refs and OGC suffix
just update-sources --element bluefin/gum.bst

git diff
just validate
```

The updater needs Python 3, `just`, Podman, `gh` (authenticated for GitHub release
lookups), and `curl` (Tailscale's package feed and junction/patch sync).
BuildStream runs in the usual container.
It edits local files only: no commits, pushes, workflow dispatches, or PRs.
Run only one updater at a time in a checkout, and avoid editing its target files
while it runs.

“All” means the sources managed by the tracker, not every element or dependency
inside upstream junctions. The source list lives in `scripts/update_sources.py`;
CI reads its matrix from there too. Release assets advance their URLs before
BuildStream tracks checksums. Tracking explicitly targets **x86_64 only** for now,
including the OCI source in `brew-tarball.bst`. Architecture-specific ARM URLs and
checksums stay pinned together, so the two architectures may have different
versions. Shared sources and junctions still advance; this is not an ARM build
validation or removal of ARM support. Core updates
derive the freedesktop-sdk pin from GNOME Build Meta and run `just patch-sync`
plus `just patch-drift-check`; never track the SDK independently.

### Kernels and the next stream

Both `core/linux-fdsdk.bst` (standard images) and `core/linux-ogc.bst` (gaming)
are local overrides, not kernel pins inherited from the SDK junction. The default
pass, `--group bundle`, and CI's shared matrix include them. `--group kernels`
updates just these elements; `--element core/linux-ogc.bst` works too. Tracking
preserves the checkout's configured series: testing currently restricts updates
to `v7.2.*` / `v7.2.*-ogc*`, while next permits `v*` / `v*-ogc*`, including RCs.
The OGC module-release suffix (`ogc-localversion`) is derived from its tracked tag;
an unrecognizable tag fails and restores the entire element. After tracking, the
updater runs `bst source fetch --deps none` for each kernel on x86_64. This fetches
the complete source set and applies any downstream patch queues before the pin is
accepted or recorded for CI. A fetch or patch failure restores the element's
starting contents, including local edits and the OGC suffix, while other updates
continue. Existing patches are never automatically dropped to make a bump pass.

Shared package updates land through testing and sync to next, but kernels and
junctions are next-owned. In a separate feature worktree based on `upstream/next`,
run these once the shared updater is present there:

```bash
just update-sources --group core-junctions
just update-sources --group kernels
```

The next tracker runs both groups into its existing PR. Kernel-containing next
updates do not enable auto-merge; an existing PR's auto-merge is disabled before
pushing a kernel change. Junction-only updates retain their existing policy.
Testing kernel updates remain in the single non-junction bundle, with review notes.

Source fetching is not compilation or hardware validation. Before shipping,
review the kernel source changes and any downstream patches, then build both
kernels and their NVIDIA consumers (these builds are **not** run by the updater):

```bash
just bst build core/linux-fdsdk.bst bluefin-nvidia/nvidia-drivers.bst
BUILD_GAMING=true just bst build core/linux-ogc.bst bluefin-nvidia/nvidia-drivers.bst
```

The `build` label is for maintainers only. Contributors should ask a maintainer
to apply it when CI image builds are needed. Maintainers should inspect each
relevant variant's result: NVIDIA and gaming jobs currently allow failure, so a
green aggregate is not proof that those kernels/drivers built. Boot verification
is still needed before release.
When the FDSDK junction advances, also compare its kernel recipe, `patches/linux/`,
`files/linux/config-utils.sh`, and `files/linux/fdsdk-config.sh` with our vendored
copies. Reconcile changes while preserving Dakota's configuration; the updater
prints a review reminder but does not overwrite these files automatically.

### Release assets and failures

Tailscale uses `Tarballs.amd64` from its
[stable package feed](https://pkgs.tailscale.com/stable/?mode=json), not the latest
GitHub release: a Git tag may exist without a matching Linux archive. The updater
validates the filename and lets BuildStream track its checksum; a malformed feed
or unavailable download fails without changing the existing pin.

An individual failure restores that update's starting files (the entire element
or junction/patch group), continues the remaining updates, and causes
a nonzero exit. Successful updates remain for review. Validation and builds are
separate; successful [source tracking](https://docs.buildstream.build/master/using_commands.html#bst-source-track)
alone does not prove that updated sources build or that downstream patches apply.
`--group tracked` and `--group tarballs` can rerun
those subsets. `--record-dir` is for CI bundle artifacts, not needed locally.

## Desktop integrations

Keep the established desktop defaults, with fuzzy application search, Tiling
Shell, and BudsLink enabled. BudsLink's default panel stays hidden until a
supported device is present. Syncthing Toggle, Tailscale Quick Settings, the
extra audio panel/hider/renamer, and Power Status Color are installed but
opt-in through the Extensions app. Their required backends
remain available; enabling a control should not require installing missing
native software.

- **Sync Folder (Syncthing):** the opt-in Quick Settings control prepares a
  same-UID, rootless Syncthing container through
  [Podman's user Quadlet integration](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html).
  Its extension element explicitly declares Podman (including the user Quadlet
  generator), a POSIX shell, GJS, libsoup 3, `xdg-user-dirs`, and Dakota's core
  utilities as runtime dependencies, alongside GLib and GNOME Shell. Install the complete
  `extensions/syncthing-toggle/` directory, including hidden deployable assets;
  `service.js` and `syncthing.container.in` are required runtime assets, not
  build-only files. Keep the extension-local schemas strictly compiled and
  install the schema XML globally as well.
  `bluefin/syncthing.bst` still installs the native `syncthing.service` user unit
  so existing stopped configurations can be inspected safely during migration;
  preserve existing state, folders, and user startup choices. Fresh runtime
  setup uses available XDG Documents locally and unpaused, with other XDG
  presets paused; it does not create `~/Sync` or pair/share with peers without
  explicit consent. Dakota's `start-stop-only=true` dconf default keeps the
  sharing switch independent of login startup. No service is started for every
  user automatically, and no identities, credentials, personal peer settings,
  or user Quadlets are generated during image construction.
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

Run `just bst build bluefin/common.bst` to exercise the patch against the pinned
source. A source rewrite that invalidates the patch must be reviewed, not
worked around by restoring a local config. Check glyph rendering in a booted
image.
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
| Open a PR without running `just validate` | Wastes everyone's time |
