---
name: dakota-workstation
description: Dakota host Homebrew integration and workstation-specific services.
---

# Dakota workstation integration

## Route the task

- Host Homebrew packaging or a damaged persistent prefix: read
  [`references/host-homebrew.md`](references/host-homebrew.md).
- End-user `ujust` recipe changes: load `dakota-ujust`.
- Local image update testing: load `dakota-image`.

## Host Homebrew invariants

- Invoke brew through `/home/linuxbrew/.linuxbrew/bin/brew`; the
  `/var/home/linuxbrew` spelling can make bottle prefix detection fail.
- Wherever the image supplies GCC for host Homebrew source builds, it must also
  supply GNU Make in the system PATH.
- `/home/linuxbrew/.linuxbrew` is persistent user data. Image upgrades do not
  repair a partially installed Ruby gem or damaged prefix; never delete it as a
  routine fix.
- Fix shared path regressions in `projectbluefin/common` when possible, while
  respecting the prohibition on all writes to `ublue-os/*`.

## Service and integration changes

1. Trace the element that installs the file and the OCI layer that composes it.
2. Confirm whether the state is image-owned or persistent user data.
3. Make service enablement declarative in BST install commands or presets.
4. Validate first-install, update, and rollback behavior separately when state
   persists across deployments.
5. Run `just validate` and the narrowest boot or integration test that exercises
   the change.

Do not paper over host integration failures with DNF, RPMs, or mutable
post-install package operations.
