---
name: e2e-ci
description: Dakota boot and smoke gate patterns. Covers inline boot-check, testsuite usage, and where observational smoke belongs. Use when changing boot-check, QEMU, publish smoke, or testsuite wiring.
metadata:
  context7-sources:
    - /bootc-dev/bootc
    - /websites/github_en_actions
---

# E2E / Boot CI

## Overview

Dakota uses **two different signals** after publish:
- **boot-check** — hard gate, fast, deterministic, blocks promotion
- **smoke** — observational, slower, flaky in VMs, should not block publish

Mixing them is how agents turn healthy publishes into red pipelines.

## When to Use

Use when working on:
- `.github/workflows/publish.yml` boot-check logic
- `.github/workflows/publish-smoke.yml`
- `run-testsuite.yml`
- inline QEMU boot flows
- `bootc install to-disk` usage in CI
- decisions about what should or should not block `:testing`

## When NOT to Use

- Generic workflow trigger/ownership questions → `workflow-map.md`
- Reusable workflow token issues or cache-dir failures → `ci-tooling.md`
- Stable promotion and release gating → `release-promotion.md`

## Core Process

1. **Choose the right gate class first.**
   - Hard gate: boot/install/SSH/GDM sanity → inline boot-check
   - Observational: AT-SPI, UX drift, slow desktop behavior → testsuite smoke
2. **Keep the hard gate small and deterministic.**
   - install image
   - boot VM
   - wait for SSH
   - verify `multi-user.target` and `gdm.service`
3. **Keep observational smoke outside the critical publish workflow.**
4. **Use the documented bootc raw-image pattern.**
5. **Use the testsuite wrapper workflow, not ad-hoc duplicate wiring.**

## Hard Gate Pattern

For raw disk images in CI, follow the documented bootc path:

```bash
fallocate -l 30G disk.raw
sudo podman run --rm --privileged --pid=host --ipc=host \
  --security-opt label=type:unconfined_t \
  -v /dev:/dev \
  -v /var/lib/containers:/var/lib/containers \
  -v "$(pwd):/data" \
  "${IMAGE}" bootc install to-disk \
    --generic-image \
    --filesystem xfs \
    --via-loopback /data/disk.raw \
    --wipe
```

Then attach the resulting raw file on the host and continue with QEMU boot checks.

## Diagnosing E2E Failures That Live Upstream

Dakota does not own any behave/step code — `tests/`, `steps/`, and the rerun
retry logic all live in `projectbluefin/testsuite`. When an E2E/smoke run
fails with an error that looks like GNOME Shell JS or Python step code
(`AttributeError`, `TypeError: ... is undefined`, `ConfigError: No steps
directory`), do not assume Dakota's workflow wiring is at fault. Check the
upstream testsuite first:

1. **Confirm the failure is current, not historical.** `gh run view <id>
   --repo projectbluefin/dakota --log-failed` gives the exact traceback and
   commit under test. A failure from weeks ago may already be fixed upstream.
2. **Diff the pinned tag against testsuite `main`:**
   ```bash
   gh api repos/projectbluefin/testsuite/compare/v1...main --jq '{ahead,behind}'
   ```
   `ahead: 0` means the `@v1` floating tag Dakota calls (`e2e.yml`,
   `run-testsuite.yml`) already includes everything on `main` — there is
   nothing to re-pin.
3. **Only if `v1` is behind `main`** is there a real Dakota-side action: open
   an issue/PR against `projectbluefin/actions` (or ping testsuite
   maintainers) to move the tag, per the "pin once in the wrapper" rule above.
4. **If the tag is current, re-run the workflow** (`workflow_dispatch` on
   `e2e.yml`, or wait for the next `publish-smoke.yml` run) to get a fresh
   result before concluding anything is still broken.

This was the resolution path for [dakota#627](https://github.com/projectbluefin/dakota/issues/627)
(`eval_js` AttributeError, undefined `_do_not_disturb`, and a behave rerun
`ConfigError`) — all three were already fixed in `projectbluefin/testsuite`
`main`, and the `@v1` tag Dakota consumes was already even with `main`, so no
Dakota workflow change was needed.

## Observational Smoke Rule

A reusable-workflow call job cannot be made truly non-blocking with
`continue-on-error`. If the smoke suite lives inside `publish.yml`, its failure
still paints the publish workflow red.

**Rule:** run smoke in a separate follow-up workflow triggered by successful
publish, e.g. `publish-smoke.yml`.

## Testsuite Rule

Always call the local wrapper workflow:
- `run-testsuite.yml`

Do **not** wire `projectbluefin/testsuite` directly from every caller. Pin once
in the wrapper, then inherit it everywhere.

## Installer Post-Boot Assertions (fisherman)

Dakota does not own installer/fisherman source (see `installer.md` for the
repo boundary), but the *installed system* it produces is Dakota's problem —
so post-boot e2e assertions for a fisherman-driven `bootc install` belong in
the testsuite's install-flow suite, wired through `run-testsuite.yml` like
any other suite.

[dakota#651](https://github.com/projectbluefin/dakota/issues/651) tracks
three assertion gaps against a system installed via fisherman (the
`bootc-installer` Go backend). Issues are disabled on `tuna-os/fisherman`, so
the source fixes are tracked as separate issues and only the e2e coverage
lives here:

| # | Assertion (post-boot, on the installed target) | Source fix tracked at |
|---|---|---|
| 1 | `flatpak list --system --app` must **not** list `org.bootcinstaller.Installer` (or `.Devel`) — `CopyFlatpaks` must exclude the installer's own Flatpak from the copied system store, not just rely on the firstboot `bluefin-remove-installer.service` cleanup as the only backstop. | fisherman issue 1 |
| 2 | `efibootmgr -v` must show `BootCurrent` plus a Boot entry for the install — requires the installer's `podman run` to bind-mount host `/sys/firmware/efi/efivars` (`-v /sys/firmware/efi/efivars:/sys/firmware/efi/efivars`) so `efibootmgr` can reach host UEFI variables from inside the install container. | fisherman issue 2 |
| 3 | `/proc/cmdline` must contain a parseable LUKS UUID via **either** `rd.luks.uuid=` or `rd.luks.name=` — confirms the `luks-tpm2-autounlock` `rd.luks.name=` parsing fix works against what fisherman actually writes to the bootloader config on a LUKS install. | projectbluefin/common issue 385 |

**Do not add these as a new inline boot-check gate.** They test the installer
path (`bootc install to-disk`/`to-filesystem` invoked via fisherman with
LUKS), which is a different code path than Dakota's own generic-image
raw-disk build used by `boot-vm`/`generate-bootable-image`/`boot-test`
(see Hard Gate Pattern above and `Justfile`'s `generate-bootable-image`).
Mixing the two turns the fast deterministic hard gate into a second,
installer-shaped e2e suite — the exact anti-pattern called out in Red Flags.

**Sequencing:** the three checks above will fail against current fisherman —
they are gaps in test *coverage*, not yet-passing assertions. Land them in
the testsuite install-flow suite as `xfail`/skip-until-fixed (or gated behind
the source PR merging), then flip to blocking once each source fix ships in
a nightly. Do not block unrelated Dakota publishes on assertions that verify
someone else's unmerged fix.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Smoke is green locally, so it can gate publish." | VM timing says otherwise. Keep publish gates deterministic. |
| "I'll just make smoke optional with `continue-on-error`." | Not on a reusable-workflow call job. Split the workflow instead. |
| "bootc already knows the defaults; I can skip the explicit flags." | CI has punished that repeatedly. Use the documented raw-image path. |
| "The testsuite workflow is easy enough to copy here." | Duplicate wiring drifts. Use the wrapper. |
| "Fisherman is a different repo, so its e2e coverage isn't Dakota's job." | Fisherman issues are disabled; the installed system it produces is still Dakota's problem. Track coverage gaps here, fix source elsewhere. |
| "Let's just add the LUKS/UEFI checks to the existing boot-check gate." | That gate tests Dakota's own generic raw-disk build, not the fisherman install path — wrong suite, wrong code path. |

## Red Flags

- AT-SPI smoke in the hard publish path
- host loop-device hand-rolling when bootc already supports `--via-loopback`
- direct calls to upstream testsuite from multiple workflows
- red publish runs caused by observational smoke
- boot-check growing into a second full e2e suite

## Verification

- [ ] The hard gate only checks boot/install sanity
- [ ] Smoke runs outside the critical publish workflow
- [ ] `bootc install to-disk` uses the documented raw-image pattern
- [ ] Testsuite calls go through `run-testsuite.yml`
- [ ] The resulting pipeline is faster and more deterministic, not more ambitious
- [ ] Installer/fisherman post-boot assertions stay in the testsuite install-flow suite, not the inline boot-check gate
