---

name: bst-overrides
description: Governs when and how to create junction overrides in dakota. Upstream-first principle — local overrides are last resort. Covers patch_queue overrides, exit conditions, and how to evaluate whether an override is justified. Use when deciding whether to override gnome-build-meta or freedesktop-sdk content, adding temporary local overrides, or removing override debt after upstream catches up. Dakota must never compile its own GCC or carry local GCC toolchain workarounds; we align with GNOME OS and upstream refs instead.
metadata:
  context7-sources:
    - /apache/buildstream
    - /websites/github_en_actions
---

# BST Junction Overrides

Load when creating, evaluating, or removing BuildStream junction element overrides in `projectbluefin/dakota`.

## When to Use

Use when you need to decide whether a local override is justified, add a temporary junction override, or remove one after upstream catches up.

## When NOT to Use

- End-to-end patch lifecycle work after deciding an override is required → `patch-junctions.md`
- Routine package updates that stay inside Dakota-owned elements → `update-refs.md`
- Generic BuildStream syntax reference → `buildstream.md`

## Core Process

1. Check whether upstream already fixed the problem.
2. Prefer an upstreamable patch or junction bump.
3. Use a local override only as a last resort.
4. Record the exit condition so the override can die.
5. Revisit overrides whenever junction refs move.

## Hard Policy: No Local GCC Toolchain Workarounds

Dakota will not compile its own GCC, ship a local GCC bootstrap toolchain, or introduce local compiler-package hacks to work around upstream build failures.

If a dependency fails to build under the baseline toolchain, the correct action is:

1. Check the upstream GNOME OS / `gnome-build-meta` / `freedesktop-sdk` baseline.
2. Match the upstream junction ref instead of inventing a local toolchain.
3. Use an upstream patch or a junction bump when possible.
4. Only use a local override if there is no upstream-aligned path and it has a documented exit condition.

This policy is explicit and non-negotiable: do not build a custom GCC under any circumstance.

## Core Principle: Upstream-First

Dakota inherits most elements from `gnome-build-meta` (GBM) and `freedesktop-sdk` (fdsdk) via BST junctions. The correct workflow is always:

1. **Check if upstream already has the fix** — if yes, bump the junction ref
2. **Submit a fix upstream** — patch the upstream project, reference the upstream PR
3. **Override locally as a last resort** — only when upstream won't or can't fix in time

Local overrides are maintenance debt. Every override needs an exit condition.

## What Is a Junction Override?

By default, `elements/gnome-build-meta.bst` and `elements/freedesktop-sdk.bst` use the refs from the upstream junction. An override replaces a specific upstream element with a local version.

**Do NOT edit junction `.bst` files directly.** Overrides are applied via `patch_queue` source in the junction file, or by providing a local element that shadows the junction element.

## Override Patterns

### Patch Queue Override (Preferred)

For changes that should eventually go upstream, add a patch to the junction's `patch_queue`:

```yaml
# In elements/gnome-build-meta.bst
sources:
- kind: git_repo
  ...
- kind: patch_queue
  path: patches/gnome-build-meta
```

Patches in `patches/gnome-build-meta/` apply in alphabetical (filename) order. See `patch-junctions.md` for the full patch lifecycle.

### Element Shadow Override

To completely replace an upstream element, create a local element at the same path the junction would provide. Use sparingly.

## Evaluating Whether to Override

| Question | If yes → |
|---|---|
| Is the fix already in upstream's current ref? | Bump junction ref instead |
| Will upstream accept a fix within the current cycle? | Submit PR upstream, add temporary patch with `Upstream-Status: Submitted` |
| Is this dakota-specific (not appropriate upstream)? | Local override is justified; document why |
| Is this a security backport? | Patch is justified; link to CVE and upstream fix |

## Exit Conditions

Every override file must have an exit condition comment:

```yaml
# Exit condition: Drop after fdsdk ships X release
# Exit condition: Drop once gnome-build-meta gnome-50 merges MR !NNN
# Exit condition: Permanent — dakota-specific, not upstreamable
```

Without an exit condition, the override becomes permanent maintenance debt with no path to removal.

## Checking Upstream Status

```bash
# Check if a fix is already in GBM gnome-50:
gh api repos/GNOME/gnome-build-meta/commits?sha=gnome-50 | jq '.[].commit.message' | grep -i <fix>

# Check if fdsdk has the fix in the current release tag:
gh api repos/freedesktop-sdk/freedesktop-sdk/tags --jq '.[0].name'
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just override it locally for now." | Local overrides are maintenance debt unless they have a clear exit path. |
| "Editing the junction file directly is faster." | Faster to create debt, yes. Use the override mechanisms the repo expects. |
| "We'll remember to drop the override later." | You won't unless the exit condition is written down. |

## Red Flags

- Local override with no upstream issue/PR reference
- No stated exit condition
- Direct edits to junction files as a convenience move
- Override surviving multiple junction bumps without re-evaluation

## Verification

- [ ] Upstream was checked before creating the override
- [ ] The local override mechanism is the narrowest one that works
- [ ] An exit condition is documented
- [ ] The override is discoverable and revisitable at the next junction bump

## Lessons Learned

### Alphabetical patch ordering matters — 0004 is higher priority than 0003 (2026-06-07)

Patch files in `patches/<junction>/` apply in alphabetical (filename) order. Gaps in numbering
are intentional — they leave room to insert patches between existing ones without renaming. Do
not fill gaps just to make the sequence look clean:

```
patches/freedesktop-sdk/
  0001-project-Specify-more-limits-to-the-CAS-configs.patch
  0002-project.conf-Add-GNOME-CAS-servers.patch
  0004-openssh-Use-etc-ssh-as-sysconfdir.patch   ← gap is intentional
  0005-openssh-Include-ssh-_config.d-.conf.patch
```

When inserting a new patch between 0004 and 0005, name it `0004b-...` or `0004c-...` so the
alphabetical order is preserved without renaming `0005+`.

### `gnome-build-meta` currently has only one patch — it's not a typo (2026-06-07)

`patches/gnome-build-meta/disable-lorry-mirrors.patch` is the only GBM patch. Dakota tracks
the most recent GBM ref (current nightly), which means most fixes are already upstream. The
single-patch state is healthy — it means minimal maintenance debt.

### Verify upstream before adding a patch (2026-06-07)

Before adding a new patch to `patches/<junction>/`:
```bash
# Check if fdsdk already has the fix on the current release tag:
gh api repos/freedesktop-sdk/freedesktop-sdk/tags --jq '.[0].name'

# Check if GBM gnome-50 already has the fix:
git -C ~/.cache/buildstream/sources/git_repo/<gbm-mirror>.git \
  log --oneline origin/gnome-50 | head -20
```

Adding a patch for something already upstream wastes maintenance cycles — junction bump is
cheaper.

### Override ledger — full audit against gnome-50 (2026-07-08)

Case-by-case status of every junction override, audited against gbm 50.2-2 (c74f623)
and fdsk 25.08.13. Re-run this audit at every gbm junction bump.

Overrides in `elements/gnome-build-meta.bst`:

| Override | Why | Exit condition |
|---|---|---|
| `freedesktop-sdk.bst` | Must pin the exact fdsk ref gbm uses so artifacts pull from gbm.gnome.org | Permanent, but the ref must always equal `elements/freedesktop-sdk.bst` in gbm at our pinned commit |
| `core/meta-gnome-core-apps.bst` | Strip GNOME core apps from OCI image | Permanent, dakota-specific |
| `gnomeos-deps/bootc.bst` | Permanent policy: dakota always ships pure upstream bootc-dev/bootc (auto-tracked), never gbm's pin | Permanent — never remove, even if gnome-50 catches up |
| `gnomeos-deps/plymouth-gnome-theme.bst` | Bluefin branding | Permanent, dakota-specific |
| `oci/integration/os-release.bst` | Bluefin os-release | Permanent, dakota-specific |
| `gnomeos/initramfs/signed-modules.bst` | Unsigned modules (no GNOME signing key) | Permanent, dakota-specific |
| `plugins/buildstream-plugins*.bst` | Share plugin junctions with parent project | Permanent, structural |

The fdsk component-override block in `elements/freedesktop-sdk.bst` must be byte-equivalent
to gbm's own `elements/freedesktop-sdk.bst` overrides (verified identical 2026-07-08). Diff
check at every bump:

```bash
curl -fsSL "https://gitlab.gnome.org/GNOME/gnome-build-meta/-/raw/<gbm-sha>/elements/freedesktop-sdk.bst" -o /tmp/gbm-fdsk.bst
diff <(grep -oE 'components/[^:]+:.*' /tmp/gbm-fdsk.bst | sort) \
     <(grep -oE 'components/[^:]+:.*' elements/freedesktop-sdk.bst | sed 's/gnome-build-meta.bst://' | sort)
```

### fdsk junction ref must match the ref gbm pins — cache reuse depends on it (2026-07-08)

Dakota overrides gbm's `freedesktop-sdk.bst` with its own junction element. If our fdsk
ref differs from the one gbm pins at our gbm commit, every fdsk-derived element gets a
different cache key than upstream and gbm.gnome.org artifacts become unreachable —
silently forcing local compiles. Found in the wild: testing pinned fdsk 25.08.12 while
gbm 50.2-2 expects 25.08.13.

Check before merging any junction bump:

```bash
curl -fsSL "https://gitlab.gnome.org/GNOME/gnome-build-meta/-/raw/<gbm-sha>/elements/freedesktop-sdk.bst" | grep -m1 ref:
grep -m1 ref: elements/freedesktop-sdk.bst   # must match
```

Auto-generated `auto/track-core-junctions` PRs bump both atomically, but if they go
stale against testing (e.g. after a patch-queue removal), rebase to a clean one-line
ref change rather than merging the stale diff — stale branches can resurrect deleted
`patch_queue` sources.

`patches/freedesktop-sdk/` must also stay byte-identical to GBM's
`patches/freedesktop-sdk/` directory at the pinned GBM commit. `just
patch-drift-check` downloads GBM's patch queue for that commit and diffs it against
the local queue; the Validate workflow runs it in CI so drift fails before cache
keys diverge from gbm.gnome.org artifacts.

### What busts a BST cache key (2026-07-08)

Grounded in /apache/buildstream arch_cachekeys.md. An element's strong key covers: its
own config/variables/env, source refs, and all build-dependency keys, recursively.

- Junction ref change → invalidates every element that junction provides (widest cone)
- `project.conf` options/variables → project-wide invalidation
- Leaf element ref bump (tailscale, common, bootc) → only that element + reverse deps
- OCI base-layer bump (common) → OCI layer chain only, no compile invalidation
- Workflow/Justfile/docs changes → zero cache impact

Merge ordering rule for queued update PRs: leaf bumps first, junction bumps last, one
at a time, each verified green before the next.

### Prefer upstream alignment over local compiler workarounds (2026-07-08)

When an upstream dependency fails under the baseline toolchain, do not invent a local GCC toolchain, local compiler flags, or a custom element to bypass the issue. That approach creates maintenance debt and diverges Dakota from the upstream GNOME OS baseline.

The correct approach is to match the upstream GNOME OS / `gnome-build-meta` / `freedesktop-sdk` ref that already works, then keep Dakota on that baseline until upstream catches up. In practice, this means:

- Remove local override elements that exist only to work around toolchain behavior.
- Prefer an upstream-aligned junction ref over a local compatibility shim.
- Keep the patch queue clean and avoid introducing compiler-specific hacks.
- Never compile our own GCC under any circumstance.

### Void-override pattern to remove an unwanted junction element (2026-07-08)

To remove a junction-provided component entirely (not patch it), override it to an empty
`kind: stack` element — the same pattern gnome-build-meta uses for `void/zenity.bst`.
Dakota provides `elements/bluefin/void.bst` for this.

```yaml
# elements/freedesktop-sdk.bst
config:
  overrides:
    components/frei0r.bst: bluefin/void.bst
```

Case study — frei0r removal:

- frei0r v3.1.3 fails to compile under GCC 15 (SSE intrinsic type errors,
  dyne/frei0r issues 228 and 239), and no upstream artifact cache carried
  Dakota's cache key for it (our junction overrides shift the key).
- `gstreamer-plugins-bad` lists frei0r as a dep and builds with
  `-Dfrei0r=enabled`, but its frei0r wrapper bundles its own `frei0r.h`
  (`gst/frei0r/frei0r.h`) — it builds fine with frei0r voided and simply
  dlopens nothing at runtime when no frei0r plugins are on disk.
- Cache impact check before committing: if everything downstream of the
  element is already `waiting` (uncached), the void override is cache-neutral.
  Verify with `just bst show oci/bluefin.bst` state counts before/after.

Also note: a failed build gets cached as a failed artifact. `bst show` reports
the element as `failed` and retries exit immediately. Clear it with
`just bst artifact delete <element>` before rebuilding (see debugging.md).

When passing `--format` strings to `just bst show`, avoid spaces — the Justfile
recipe word-splits arguments. Use `%{name}--%{state}` style separators.

### Local patch queues on junctions completely invalidate upstream cache reuse (2026-07-10)

Applying any local patch queue (`patch_queue` source) to a junction (like `gnome-build-meta.bst` or `freedesktop-sdk.bst`) modifies the junction's cryptographic source hash and cache key. Because BuildStream recursively derives downstream element keys from their junction's key, this downstream-only change invalidates the entire imported project graph.

- **Consequence:** Carrying local patches (like `disable-lorry-mirrors.patch`) on a junction silently forces local compiles for massive components (like WebKit) by preventing cache reuse against the official public upstream cache (`gbm.gnome.org:11003`).
- **Fix:** Keep junctions 100% clean of downstream patch queues. If a patch is required, submit it upstream first or bump the junction ref. Removing the patch queue on `gnome-build-meta` immediately restored 1053 out of 1090 cached elements (96% cache hit rate).

### Overriding a single file a junction ships into /etc (overlap-whitelist pattern) (2026-07-19)

To replace one file that an upstream junction component installs (not patch the
junction, not shadow the whole element), ship a Dakota `bluefin/*.bst` element
that installs the replacement to the same path, and use `overlap-whitelist` to
win the compose overlap. This is the same mechanism `bluefin/sudo-rs.bst` uses
to take over `/usr/bin/sudo` from fdsdk's `components/sudo.bst`.

```yaml
public:
  bst:
    overlap-whitelist:
    - /etc/pam.d/system-auth   # literal path, not a %{var}
depends:
- freedesktop-sdk.bst:components/linux-pam.bst   # forces staging AFTER the stock file
```

Two facts that make this safe and deterministic:

- **Staging order = overlap winner.** Whitelisting only silences the warning; the
  element staged *later* wins. A runtime `depends:` on the component that ships
  the original guarantees the override stages after it. (`sudo-rs.bst` gets away
  without the explicit dep, but declaring it removes the ambiguity.)
- **/etc vs /usr/etc matters.** fdsdk `sysconfdir=/etc`, so config like
  `linux-pam`'s pam.d lands in real `/etc`, and the compose includes `/etc`.
  `oci/bluefin.bst` only merges `/usr/etc -> /etc` (`cp -a`, `/usr/etc` wins) —
  it never touches files already in `/etc`. So an `/etc` override is NOT
  clobbered by that merge. If you instead need to override something a component
  ships to `/usr/etc`, your override must also go to `/usr/etc` (mine would lose
  to the merge otherwise) and the whitelist path must be the `/usr/etc` one.

Case study — issue #953, fingerprint for sudo/polkit: `bluefin/fprintd-system-auth.bst`
ships a full `/etc/pam.d/system-auth` with `auth sufficient pam_fprintd.so` above
`pam_unix`. PAM has no drop-in for the aggregate `system-auth` stack and there is
no authselect on this image, so a whole-file override is the only option. sudo
(`/etc/pam.d/sudo`) and polkit (`/usr/lib/pam.d/polkit-1`) both reach it via
`auth include system-auth`. Note Dakota builds sudo-rs without the `pam-login`
cargo feature (`default = []`), so sudo-rs opens the `sudo` PAM service (not
`sudo-i`) for `sudo -i` too — both paths include `system-auth`. Re-sync the
copied stock stack at every fdsdk bump.

### Select variant-specific kernels at the junction boundary (2026-07-28)

Kernel consumers such as initramfs assembly, unsigned module collection, and NVIDIA
module builds all depend on `freedesktop-sdk.bst:components/linux.bst`. When image
variants need different kernels, make that path resolve conditionally in the
freedesktop-sdk junction override. Swapping only the final runtime dependency can
pair modules built for one kernel with another kernel at boot.

If a required config change is present on freedesktop-sdk `master` but not the
pinned release branch, prefer a leaf kernel element over patching the junction.
Copy the pinned kernel source and config, state an exit condition tied to the
upstream commit, and keep the junction source itself byte-aligned with
gnome-build-meta. This invalidates the kernel and its reverse dependencies instead
of the entire SDK graph. Validate both option values with `bst show`, because the
default graph alone does not exercise the conditional kernel.

For Linux 7.0 and 7.1, WCN7850 (`17cb:1107`) support is controlled by
`CONFIG_ATH12K`. Even though the bound PCI module is named `ath12k_wifi7`,
that single symbol builds both `ath12k.ko` and the Wi-Fi 7 family module;
there is no separate `ATH12K_PCI` or `ATH12K_WIFI7` Kconfig option in those
trees. Verify the selected kernel's Kconfig, Wi-Fi 7 PCI ID table, and
`/usr/lib/firmware/ath12k/WCN7850/hw2.0/` payload together.
