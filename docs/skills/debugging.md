---
name: debugging
description: Debug Dakota BuildStream build failures. Use when `just bst build` fails, `bst show` errors, source fetch breaks, or a package builds but does not land correctly in the image.
metadata:
  context7-sources:
    - /apache/buildstream
---

# Debugging Build Failures

## Overview

This skill is for **element-level debugging**.
Use it when the package/build graph is the problem, not when GitHub Actions plumbing is the problem.

## When to Use

Use when:
- `just bst build ...` fails
- `just bst show ...` errors
- source fetch or ref tracking fails
- compile/install/staging steps fail
- the element builds but the final image is missing content

## When NOT to Use

- CI trigger, token, cache, or workflow problems → CI skills
- Writing a new element from scratch → `add-package.md` or `buildstream.md`
- OCI layer design questions → `oci-layers.md`

## Core Process

1. **Classify the failure first.**
   - graph/YAML
   - fetch/ref
   - compile
   - install/staging
   - image composition
2. **Use the cheapest inspection command first.**
   - `bst show` before `bst build`
   - `artifact log` before guessing
   - `artifact list-contents` before blaming compose layers
3. **Reproduce in the sandbox if needed.**
4. **Only escalate to full-image build after the element is clean.**

## Quick Reference

| Action | Command |
|---|---|
| Build one element | `just bst build bluefin/<name>.bst` |
| Enter build sandbox | `just bst shell --build bluefin/<name>.bst` |
| Inspect sources/graph | `just bst show bluefin/<name>.bst` |
| View build log | `just bst artifact log bluefin/<name>.bst` |
| List built files | `just bst artifact list-contents bluefin/<name>.bst` |
| Delete cached failure | `just bst artifact delete bluefin/<name>.bst` |
| Full image build after fix | `just build` |

## Failure Classes

### 1) Graph / YAML errors

Symptom: `Error loading project` before any real build starts.

Typical causes:
- bad indentation
- invalid option names or types
- missing source alias
- malformed element structure

Start with:
```bash
just bst show bluefin/<name>.bst
```

### 2) Source fetch failures

Typical causes:
- stale `ref:`
- moved upstream URL
- tarball layout mismatch

Useful fixes:
- `just bst source track bluefin/<name>.bst`
- add/update alias in `include/aliases.yml`
- use `base-dir: ""` for tarballs without a wrapping directory

### 3) Compile failures

Typical causes:
- missing build dependency
- upstream path assumptions (`/usr/sbin`, `/lib`)
- pkg-config visibility problems

### 4) Install / staging failures

Typical causes:
- missing `strip-binaries: ""` for non-ELF payloads
- forgot `mkdir -p` before symlink or install path creation
- overlap conflict
- files landing outside `/usr`

### 5) Image composition failures

Typical causes:
- element never wired into `deps.bst`
- downstream compose cache did not invalidate
- OCI layer is `stack` when it should be `compose`

## Sandbox Workflow

```bash
just bst shell --build bluefin/<name>.bst
# inside the sandbox, rerun the failing configure/build/install step
```

Use the sandbox when you know which phase failed and need to replay it interactively.
Do not open the sandbox before you even know whether the graph parses.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The build failed, so I need the sandbox immediately." | Not if `bst show` is already telling you it's YAML. |
| "CI failed, so this must be a CI problem." | Many CI failures are just element failures surfacing remotely. Classify first. |
| "The package is missing from the image, so the build must have failed." | It may have built fine and never been wired into the stack or compose step. |
| "I'll skip straight to a full image build." | That's the slowest possible feedback loop. |

## Red Flags

- opening the sandbox before reading the log
- debugging compile flags when the graph does not even parse
- assuming missing image content means source fetch failure
- rerunning full image builds for single-element syntax mistakes

## Verification

- [ ] The failure class is identified before deep debugging
- [ ] `bst show` is clean before sandbox work begins
- [ ] Logs or artifact contents were inspected before guessing
- [ ] Single-element debugging was exhausted before full image rebuilds
- [ ] The fix explains why the failure happened, not just how it was silenced

## Lessons Learned

### `Error loading project` before any build step = YAML error, not a build failure (2026-06-07)

When BST exits with `Error loading project` before any `[build]` output appears, the element has a YAML/option error — it never even started building. Run `just bst show bluefin/<name>.bst` (no build) to pinpoint the exact line. Common causes: hyphenated option names, wrong option type, missing alias, bad indentation. Do not reach for `just bst shell` until `bst show` exits cleanly.

### Invalidate stale/corrupt remote CAS cache keys with a no-op command (2026-07-03)

If a remote artifact on `cache.projectbluefin.io` is corrupted (e.g., due to partial writes or aborted builds), BuildStream may attempt to pull it and fail with a transport error or gRPC `INTERNAL` (blob download code 13). Because BuildStream does not automatically fall back to rebuilding if a pull fails midway, the build remains broken. The fix is to modify the element (e.g., adding a no-op command like `- true` in `elements/oci/bluefin.bst`) to bust the cache key, forcing a clean rebuild from dependencies.

Dakota's verified mitigation for a stale remote blob is a small, versioned marker file installed into the OCI layer: `elements/oci/layers/bluefin-layer-marker.bst` installs `files/oci/bluefin-layer-marker` at `/usr/lib/projectbluefin/cas-epoch`. Bump the marker contents when the remote cache needs a fresh layer digest so BuildStream cannot reuse the poisoned blob under the old digest/size tuple.

### Plain-text marker files need `strip-binaries: ""` (2026-07-05)

Elements that install non-ELF payloads (plain text files, shell scripts, fonts, JSON, prebuilt archives) can fail during the stripping phase even when the install command itself is correct. The symptom is a BuildStream failure with `freedesktop-sdk-stripper` exiting `127` while the element's `install-commands` are otherwise simple. The root cause is that BuildStream's default strip step is trying to process a file that is not an ELF binary. Add `variables: { strip-binaries: "" }` to the element to disable the strip step for that payload.

### Remote-build slowness is diagnosed from logs and generated config, not from workflow churn (2026-07-06)

When a remote BST build is slow or hits the workflow timeout, the first question is not "should we change the timeout again?" The first question is whether the generated BuildStream config is actually enabling remote execution and whether the run is progressing with remote cache activity. The 2026-07-06 investigation showed that a workflow can appear to be using the remote cache while still not dispatching expensive build actions to the remote execution service.

Good evidence to gather before changing anything else:

1. Confirm the workflow passes `enable-remote-execution: 'true'` to the generator.
2. Confirm the generated `buildstream-ci.conf` contains a `remote-execution:` block.
3. Inspect the build logs for remote cache activity (`Pulled artifact`, `Pulled source`, `does not have artifact/source cached`) and for evidence that the build is continuing past the initial fetch phase.
4. If the build still stalls, inspect the active element graph and the latest upstream nightly delta rather than making another workflow-only change.

This matters because repeat toggles of the same flag can create the false impression that the problem is solved while the build stays in the same state. A real fix must show up in the generated config and in the BuildStream logs. If the config is correct and the logs show remote action cache activity, the next bottleneck is likely an actual element / upstream-cache issue rather than a workflow bug.

### Ghost-lab BST builds should avoid the broken buildbarn execution path when input-root staging fails (2026-07-07)

The 2026-07-07 ghost-lab failure in `bootstrap/gcc.bst` was not a compiler regression; it was a BuildStream remote-execution input-root staging failure (`Failed to obtain input directory ".": Shard 1: Object not found`). The cluster workflow was routing both the remote execution and the artifact/source-cache path through the local buildbarn frontend, and that path failed before the compiler ever got a clean input tree.

The more reliable lab fallback is to keep the build local to the cluster runner, use the shared project caches for read-only artifact/source pulls, and avoid remote execution for this path. That preserves the speed advantage of the persistent hostPath BST cache while removing the broken buildbarn execution/storage hop from the hot path.

### Prefer upstream alignment over local compiler workarounds (2026-07-08)

Carrying custom local patches or build flag overrides in the `freedesktop-sdk` junction (such as hacking Pipewire versions or adding local GCC 15 compiler workarounds) alters the sub-project config and invalidates the cache keys for every single element in that junction. This forces the runners to build the entire base OS—including compiler toolchains, glibc, and systemd—from source, causing extremely long compile times, compiler crashes, and OOMs.

The correct fix is to align Dakota with the upstream GNOME OS / `gnome-build-meta` / `freedesktop-sdk` ref that already works, then keep the patch queue clean. Do not compile our own GCC, ship a local GCC bootstrap toolchain, or add compiler-specific hacks under any circumstance. If an upstream-aligned ref is available, use that path first; only use a local override when there is no upstream path and it has a documented exit condition.

