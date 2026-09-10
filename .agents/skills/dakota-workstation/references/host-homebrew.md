---
name: host-homebrew
description: How Homebrew runs on the Dakota host — prefix spelling rules, the GNU Make requirement, and the failure mode where a failed native gem build bricks the persistent /home/linuxbrew prefix. Use when touching brew.bst, brew-tarball.bst, common's brew files, or debugging a broken brew on an installed system.
---

# Host Homebrew

Homebrew on Dakota runs **directly on the host**. The prefix at
`/home/linuxbrew/.linuxbrew` is persistent user data: image updates and reboots
do not repair it, so any bug that corrupts it bricks brew until someone fixes
the prefix by hand.

## When to Use

- Editing `elements/bluefin/brew.bst`, `elements/bluefin/brew-tarball.bst`, or
  the brew-related files common ships (`brew-preinstall`, `20-oem-brew.sh`,
  `update.just`, `brew-preinstall.service`)
- A user-facing report that every `brew` command crashes on an installed system
- Reviewing changes that touch the toolchain content of the OCI layers
  (`elements/oci/layers/bluefin.bst`, `bluefin-nvidia.bst`)

## When NOT to Use

- General package addition → load `dakota-packaging`

## Invariants (violating either one bricks installed systems)

### 1. The image must ship GNU Make wherever it ships GCC

`bin/brew` **hard-filters PATH to `/usr/bin:/bin:/usr/sbin:/sbin`** before
running anything (see `filter the user environment` in Homebrew's `bin/brew`).
No user PATH, shell profile, or brew-installed make can ever satisfy a native
build — the toolchain **must** be in `/usr/bin`. Both
`elements/oci/layers/bluefin.bst` and `bluefin-nvidia.bst` therefore compose
`freedesktop-sdk.bst:components/make.bst` alongside `components/gcc.bst`.

Why it bricks: Homebrew's vendored-gem Bundler install is **not transactional**.
If a native extension build fails (e.g. `make` missing), the gem's Ruby files
stay in `vendor/bundle` without the matching `.so`. Ruby then loads mismatched
gem code against the built-in extension of a different version and **every brew
command crashes at startup** (for example, `brew style` installing `json` Ruby
files while portable Ruby falls back to its built-in JSON native extension).

### 2. Brew must always be invoked as `/home/linuxbrew/.linuxbrew/bin/brew`

Dakota has a real `/home` (no ostree `/var/home` indirection). Homebrew derives
its prefix from the path it was invoked through; the `/var/home` spelling makes
the detected prefix differ from the `/home/linuxbrew` prefix Linux bottles are
built for, so brew **rejects every bottle and falls back to source builds**
(which then hit invariant 1). This is why `brew-preinstall.service` failed to
install OS-managed packages before the 2026-07 incident was even noticed.

Upstream `projectbluefin/common` used to spell these paths
`/var/home/linuxbrew` because on its ostree-based targets (Bluefin, LTS)
`/var/home` is the physical directory and `/home` is a symlink into it —
there, either spelling resolves. Dakota inverts the layout (real `/home`),
which turns the spelling into the bottle-rejection failure above.
`/home/linuxbrew` is the spelling that works on both layouts and is what the
rest of the ecosystem uses (`ublue-os/brew` itself, Aurora, and bluefin's own
sudoers/OEM hooks). projectbluefin/common#997 respelled every occurrence at
the source; `elements/bluefin/common.bst` keeps a build-time guard that fails
if the `/var/home/linuxbrew` spelling ever regresses upstream — fix such
regressions in common, not with a Dakota-side rewrite.

## ChairLift cask migration

Dakota installs `ublue-os/tap/chairlift` (Project Bluefin's release), not
`frostyard/tap/chairlift`. `bluefin/common.bst` replaces the inherited Brewfile,
desktop assets and bootc policy using pinned ChairLift source. Keep common's
existing `/usr/share/chairlift/config.yml` unchanged: fork-only configuration keys
make the old Frostyard binary reject the entire file if migration is offline or
blocked. `/etc/chairlift` remains authoritative and untouched. New fork-only UI
groups inherit the fork's defaults; this migration does not integrate their
backends. Only the existing bootc staging capability is supplied, with unchanged
admin requirements and `/usr/libexec/bootc-update-stage` path. No additional
privileged helpers or policies are installed.

`/usr/libexec/dakota-brew-managed preinstall` attempts the one-time migration,
then runs generic preinstall **even if ChairLift fails**, passing common's
`--external-chairlift` option. Common excludes `chairlift.Brewfile` from generic
bundle/hash/removal handling; the dedicated installer owns both first install
and migration. Other images retain common's normal behavior without the option.
Generic preinstall must not silently install an unchecked ChairLift or remove it
during this handoff.
The wrapper returns failure when either part fails, so failures remain visible.

The handoff implementation belongs in `projectbluefin/common`, not a downstream
patch. Dakota's BST install checks common's `--capabilities` output for
`external-chairlift-v1` before changing image files. The pinned common source
includes this API. Keep that capability when updating the pin; the build rejects
older common rather than letting generic preinstall bypass the dedicated
installer.

The brew update/upgrade services and uupd's `modules.brew.path` use the wrapper
solely for shared-prefix locking. Native `update` and `upgrade` do not run the
migration or inherit its no-auto-update/cleanup settings. A pinned ChairLift or
failed migration cannot gate unrelated upgrades. Administrator overrides of uupd's
Brew path must preserve that routing. Interactive Brew and ChairLift operations
do not take this additional lock: close them while migrating; Homebrew's own
package locks are not a transaction lock across the whole migration.

The migration checks **installed receipts**, not the current tap definition, and
requires a matching old OS-managed cask record before replacing an existing
install (a Bluefin-qualified record cannot authorize a Frostyard cask). It captures
that consent with the installed receipt's SHA256 before generic preinstall drops
ChairLift from its managed set. Missing/corrupt state, third-party sources, pinned
casks and unknown receipts stop rather than authorize a replacement. For a known
legacy install that the user explicitly wants adopted, run as the prefix owner,
without sudo:

```bash
/usr/libexec/dakota-brew-managed migrate-chairlift --adopt
```

First installs and replacements must resolve to a checksummed stable Project
Bluefin release (numeric `x.y.z`, at least `0.12.2`, with the URL tag matching the
version). `latest`, prereleases, stale Frostyard-backed casks and invalid checksums
are rejected before uninstall. The download is verified before removing the old
cask. A mode-0600 atomic checkpoint at
`/home/linuxbrew/.linuxbrew/var/dakota-chairlift-migration.json` records schema 2
phases `authorized`, `prepared`, `replacing`, and `complete`. Preparation freezes
the target version, URL and checksum. A changed source receipt or prepared target
requires inspection and explicit `--adopt` reauthorization, not blind retries.

A `replacing` retry accepts the original receipt, absence after uninstall, or the
expected target receipt. If that target lacks its versioned executable links,
normal retry uses Homebrew's checksummed `reinstall` without `--zap`. A completed
migration does not consult the moving candidate or implement future upgrades;
Homebrew owns those. User removal is respected. Damage or a legacy reinstall after
completion requires explicit adoption; completion is not perpetual consent.

This is **not an atomic package transaction**: failure after uninstall temporarily
leaves ChairLift unavailable. Fix the reported error and rerun the same command;
do not delete checkpoints or fabricate preinstall state. Concurrent interactive
Brew remains unsupported. The preinstall declaration remains in the image, but
ChairLift is intentionally no longer in generic preinstall's OS-diet managed set.

The migration removes `frostyard/tap`, but never force-uninstalls its packages.
Every cask directory and formula version directory must have a readable provenance
receipt; a missing receipt blocks removal too. Other installed Frostyard packages
are reported before ChairLift is removed and must be deliberately migrated first.
Duplicate names installed from the Bluefin tap are retained. Homebrew's
`untap --force` can uninstall casks, so it is not used: after receipt checks prove
no Frostyard packages remain, developer mode
is scoped to the **untap command only**, allowing tap-only removal even when
Homebrew confuses duplicate cask tokens. No persistent developer setting changes.
See the verified [Homebrew untap implementation](https://github.com/Homebrew/brew/blob/05f17bafd849202efca55544c3312aae31a8fd23/Library/Homebrew/cmd/untap.rb),
[installed-cask receipts](https://github.com/Homebrew/brew/blob/05f17bafd849202efca55544c3312aae31a8fd23/Library/Homebrew/cask/tab.rb),
and [uupd's configurable Brew path](https://github.com/ublue-os/uupd/blob/v1.4.0/pkg/config/config.go).

Image rollback does not roll back the persistent cask or checkpoint. Older Dakota
images also carry the Frostyard Brewfile and can re-add that tap; do not run their
preinstall/upgrade jobs as a migration rollback. Test image rollback with the
Bluefin cask retained, or plan an explicit package rollback before deployment.
The bootc helper path and authorization requirements stay compatible across the
policy ID change. Automatic cask downgrade is intentionally not implemented.

Validation: `just test-chairlift-migration` exercises receipt/ownership checks,
one-time behavior, checkpoint identity, partial-install repair, fresh-source
validation, tap removal, native-upgrade independence and BST installation using
isolated Bash/jq fixtures. It also invokes common's opt-in API using a test-only
snapshot, exercises generic preinstall ownership handoff, and rejects image
assembly against old common. Refresh the snapshot from the landed common source
when advancing the pin; fixtures never supply production image content.
`just validate` includes it. Before shipping, additionally build
`bluefin/common.bst` and boot-test a fresh install and a managed Frostyard upgrade,
including an administrator config override and image rollback. Mock tests are
not evidence of successful live cask migration or GUI/polkit operation.

## Repairing a bricked prefix on an installed system

Do **not** delete the prefix (user packages live there) and do not reach for
RPM/DNF/`ujust devmode` — this is a BuildStream image.

1. Get a working `make` without touching the OS: GNU Make's `build.sh`
   bootstraps with only a C compiler (`./configure && ./build.sh`), and the
   host ships GCC.
2. Remove the partial gem installs from
   `Homebrew/Library/Homebrew/vendor/bundle/ruby/<abi>/` — the broken gems'
   `gems/<name>-<ver>`, `specifications/<name>-<ver>.gemspec`,
   `extensions/<arch>/<abi>-static/<name>-<ver>`, and `cache/<name>-<ver>.gem`.
3. Reinstall via Bundler **directly** — `brew install-bundler-gems` cannot work
   (PATH filter, invariant 1). From anywhere:

   ```bash
   HB=/home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew
   RB=$HB/vendor/portable-ruby/<version>/bin
   env -i HOME="$HOME" USER="$USER" TERM=dumb \
     PATH="$RB:<dir-with-make>:/usr/bin:/bin" \
     GEM_HOME="$HB/vendor/bundle/ruby/<abi>" GEM_PATH="$HB/vendor/bundle/ruby/<abi>" \
     BUNDLE_GEMFILE="$HB/Gemfile" BUNDLE_WITH="style" BUNDLE_FROZEN=true \
     "$RB/bundle" install
   ```

4. Verify: `brew --version`, `brew search <x>`, and `brew style <file>` in a
   tap checkout (the class of command that triggered the incident).

## Failure Modes & Recovery Traps

### Re-arming Trap: Do Not Re-run `brew install-bundler-gems`

Bundler extracts gem files **before** building native extensions. Every failed attempt recreates the exact mismatched-gem crash it was trying to fix. Never retry the high-level brew command to test if it works on an affected machine — fix the PATH and invoke Bundler directly via the repair procedure above.

### Timer Execution Environment

`brew-update.service` and `brew-upgrade.service` (systemd user units) invoke brew with the default systemd PATH. Because `bin/brew` enforces a hard PATH filter, timer-context native builds only ever see `/usr/bin`. This is why GNU Make must live in the base image, never in a user profile or prefix.
