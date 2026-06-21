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

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Smoke is green locally, so it can gate publish." | VM timing says otherwise. Keep publish gates deterministic. |
| "I'll just make smoke optional with `continue-on-error`." | Not on a reusable-workflow call job. Split the workflow instead. |
| "bootc already knows the defaults; I can skip the explicit flags." | CI has punished that repeatedly. Use the documented raw-image path. |
| "The testsuite workflow is easy enough to copy here." | Duplicate wiring drifts. Use the wrapper. |

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
