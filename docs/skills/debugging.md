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
