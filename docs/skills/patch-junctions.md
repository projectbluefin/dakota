---
name: patch-junctions
description: Policy regarding patches applied to upstream junctions (freedesktop-sdk, gnome-build-meta). State that local patch queues are deprecated/prohibited in favor of upstream-first fixes or tracking directly.
metadata:
  context7-sources:
    - /apache/buildstream
---

# Patching Junction Elements

Dakota enforces an upstream-first junction policy. Local junction patch queues are prohibited.

## The Rule

```text
NO LOCAL JUNCTION PATCH QUEUES
```

All patches previously applied to freedesktop-sdk or gnome-build-meta junctions via patch_queue source blocks have been completely removed. Dakota's build must follow upstream junctions directly.

## ⚠️ CRITICAL WARNING: PATCHES DESTROY UPSTREAM CACHE REUSE

Applying any patch or patch queue (`patch_queue` source) to a junction (`gnome-build-meta.bst` or `freedesktop-sdk.bst`):
1. **Recalculates downstream keys:** BuildStream recursively derives all downstream element cache keys from the junction's cryptographic hash.
2. **Busts cache hits:** Any patch completely invalidates the cache keys for every single element imported from that junction, making it impossible to pull from upstream public caches (like `gbm.gnome.org:11003`).
3. **Forces unfeasible compiles:** This silently forces Dakota to compile massive components (such as **WebKit**, ~9,400 steps each, taking hours) from scratch.

**Rule:** Junctions must remain 100% clean of downstream patch queues. If a patch is needed, it must be submitted upstream first. Never add local patch queues to junctions unless willing to pay the cost of hours-long WebKit cold-builds.

## Reasons for This Policy

1. **Maintenance Overhead:** Keeping downstream patches rebased and aligned with moving upstream junction refs is a heavy source of technical debt and causes frequent CI validation failures.
2. **Reproducibility:** Relying on upstream releases and official stable branches ensures our build environment is robust and reproducible.
3. **Upstream Alignment:** Issues or fixes required in base components (like systemd, Mesa, or GCC) should be fixed directly in the upstream freedesktop-sdk or gnome-build-meta repositories and then rolled into Dakota via a junction bump, rather than being patched downstream.

## Exception (Short-lived Workarounds Only)

Under extreme, time-sensitive circumstances where a build is blocked and a junction bump cannot carry the fix immediately, a temporary patch may be introduced.
- It must be temporary and targeted for deletion in the very next junction bump.
- It must have an explicit Upstream-Status: Submitted <URL> header tracking the PR/MR submitted to the upstream project.

```patch
From: Author <email>
Date: ...
Subject: [PATCH] Temporary workaround for block

Upstream-Status: Submitted https://gitlab.gnome.org/GNOME/gnome-build-meta/-/merge_requests/NNN
Exit condition: Drop after gnome-build-meta tracks release containing this merge request
```
