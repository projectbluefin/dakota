---
name: e2e-ci
description: Dakota's post-build verification gates — the inline QEMU boot-check that blocks stream-tag promotion, the separate observational smoke workflow, and the single testsuite wrapper. Load when changing boot-check, QEMU, smoke, or testsuite wiring.
---

# E2E and Boot CI

## Overview

Dakota separates two verification signals by design. The boot-check is a
fast, deterministic hard gate inside the publish workflow: the image must
install and boot before a stream tag moves. Observational smoke is slower,
VM-flaky desktop testing that must never block a healthy publish, so it lives
in its own workflow. Collapsing the two turns flaky assertions into red
publishes.

## When to use

- Changing the `boot-check` job or the flags it passes to `bootc install`
- Changing the observational smoke workflow or the testsuite wrapper
- Deciding whether a new assertion should block tag promotion
- Debugging a boot-check that installed but never reached SSH

## When not to use

- Install defaults shipped in the image → [installer](../installer/SKILL.md)
- Permissions, tokens, cache config → [ci-tooling](../ci-tooling/SKILL.md)
- Promotion to `:stable` → [release-promotion](../release-promotion/SKILL.md)

## Authoritative sources

- `.github/workflows/publish.yml` — the inline `boot-check` gate
- `.github/workflows/publish-smoke.yml` — observational smoke, separate run
- `.github/workflows/run-testsuite.yml` — the only wrapper for the shared suite
- `.github/workflows/e2e.yml` — manual entry point for testing an image
- `scripts/check_publish_workflow.py` — executable guard on the install step

## Workflow

1. **Classify the assertion before writing it.** Install, boot, SSH, and unit
   sanity belong in the hard gate. Desktop behavior, accessibility, and UX
   drift belong in smoke.
2. **Keep the gate cheap.** It installs to a raw file via loopback, boots the
   extracted kernel directly under QEMU, waits for SSH, and checks
   `multi-user.target` plus the display manager. Anything slower or
   display-dependent belongs in smoke.
3. **Change install flags through the guard.** `check_publish_workflow.py`
   asserts which flags the install step must and must not use; run
   `just check-publish-workflow` (also part of `just validate`) after editing.
4. **Call the testsuite through the wrapper only.** Every caller goes through
   `run-testsuite.yml`, which pins the shared suite once. Wiring the shared
   workflow directly from a second caller reintroduces version drift.
5. **Test a PR's own image by dispatch, not on `pull_request`.** PRs do not
   publish an image, so an automatic smoke run would assert against a stale
   published tag rather than the change under review.

## Failure modes

### The CI boot path deliberately diverges from the shipped install defaults

The image ships install defaults for real hardware, while the boot-check
passes explicit flags for a loopback file and skips bootloader installation.
Because no bootloader entries are written, the job mounts the deployment,
extracts the kernel and initramfs, derives the ostree deployment path from
the on-disk boot tree, and boots QEMU directly with those kernel arguments.
Changing either side without the other silently breaks the gate: keep the
shipped defaults ([installer](../installer/SKILL.md)) and the CI overrides
consistent with what the guard script allows.

### A reusable-workflow call job cannot be `continue-on-error`

That single platform constraint is why smoke is a separate workflow triggered
after a successful publish rather than one more job inside it. Moving smoke
back inline makes every flaky desktop assertion a publish failure.

### Loopback partitions are not visible immediately

The install container and the host must agree on the loop device state, so
the job attaches with partition scanning and settles udev before reading the
root partition, then fails fast with the partition table dumped if the root
filesystem is absent. Removing that check turns a provisioning failure into a
confusing boot timeout.

### A headless VM has no display manager to activate

Under a headless QEMU boot the display manager stays inactive; only a
`failed` state is a real image regression. Asserting "active" instead makes
the gate fail on every successful build.

## Verification

```bash
# The gate lives in the publish workflow
rg -n 'boot-check' .github/workflows/publish.yml

# Install-step flags are guarded
just check-publish-workflow

# Smoke is a separate workflow, and the wrapper is the only testsuite caller
rg -n 'projectbluefin/testsuite' .github/workflows

# Boot the built image locally before pushing
just boot-test
```

## Related skills

- [ci-triage](../ci-triage/SKILL.md) — confirm the failure is really a gate
- [installer](../installer/SKILL.md) — the install defaults shipped in the image
- [release-promotion](../release-promotion/SKILL.md) — what the gate protects
- [vm-stack](../vm-stack/SKILL.md) — local VM boot tooling
