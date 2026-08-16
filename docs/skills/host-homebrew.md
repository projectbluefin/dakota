---
name: host-homebrew
description: How Homebrew runs on the Dakota host — prefix spelling rules, the GNU Make requirement, and the failure mode where a failed native gem build bricks the persistent /home/linuxbrew prefix. Use when touching brew.bst, brew-tarball.bst, common's brew files, or debugging a broken brew on an installed system.
---

# Host Homebrew

Homebrew on Dakota currently runs **directly on the host** (the `bluefin-cli`
nspawn design in `bluefin-cli.md` is placeholder work — `bluefin-cli.bst` is not
wired into `deps.bst` and does not ship). The prefix at `/home/linuxbrew/.linuxbrew`
is persistent user data: image updates and reboots do not repair it, so any bug
that corrupts it bricks brew until someone fixes the prefix by hand.

## When to Use

- Editing `elements/bluefin/brew.bst`, `elements/bluefin/brew-tarball.bst`, or
  the brew-related files common ships (`brew-preinstall`, `20-oem-brew.sh`,
  `update.just`, `brew-preinstall.service`)
- A user-facing report that every `brew` command crashes on an installed system
- Reviewing changes that touch the toolchain content of the OCI layers
  (`elements/oci/layers/bluefin.bst`, `bluefin-nvidia.bst`)

## When NOT to Use

- nspawn container design work → `bluefin-cli.md`
- General package addition → `add-package.md`

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
command crashes at startup** (2026-07-30 incident: `brew style` installed
`json` 2.21.1 Ruby files, portable Ruby fell back to its built-in JSON 2.18
native ext → `undefined method 'default_sort_keys_proc='`).

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

## Lessons Learned

### A failed `brew install-bundler-gems` re-arms the broken state (2026-08-01)

Bundler extracts gem files **before** building native extensions. Every failed
attempt recreates the exact mismatched-gem crash it was trying to fix. Never
retry the brew-level command to "see if it works now" on an affected machine —
fix the PATH problem first (direct Bundler invocation above), or you re-break
startup for every brew command including the timers.

### The update timers run brew with systemd's default PATH (2026-08-01)

`brew-update.service` / `brew-upgrade.service` (system units, `User=1000`)
invoke brew with the stock systemd PATH. Combined with the `bin/brew` PATH
filter, timer-context native builds only ever see `/usr/bin` — another reason
make must live in the image, not in the prefix or a user dotfile.
