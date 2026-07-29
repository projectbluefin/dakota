---
name: debugging
description: Debug Dakota BuildStream build failures. Use when bst build fails, bst show errors, source fetch breaks, or a package builds but does not land correctly in the image.
---

# Debugging Build Failures

## Overview

This skill covers element-level debugging — classifying the failure, using the cheapest inspection command first, and escalating only when necessary. It is not for CI workflow or GitHub Actions problems.

## When to use

- `just bst build ...` fails at any phase
- `just bst show ...` reports errors
- Source fetch or ref tracking fails
- An element builds but the final image is missing its content

## When not to use

- CI trigger, token, or cache problems → [ci-tooling](../ci-tooling/SKILL.md)
- Writing a new element from scratch → [add-package](../add-package/SKILL.md)
- OCI layer composition questions → [oci-layers](../oci-layers/SKILL.md)

## Authoritative sources

- `Justfile` — `bst` recipe (wraps all BST commands)
- `elements/bluefin/deps.bst` — package manifest (check wiring here)
- `elements/oci/layers/` — compose layers (check `kind: compose` here)
- `include/aliases.yml` — source URL aliases

## Workflow

1. **Classify the failure** before diving in:
   - Graph/YAML error → `bst show` fails before any build output
   - Source fetch error → download or ref resolution fails
   - Compile error → build commands fail in sandbox
   - Install/staging error → strip, overlap, or path issues
   - Image composition → element built but missing from final image
2. **Use the cheapest command first**:
   ```bash
   just bst show bluefin/<name>.bst       # catches YAML/graph errors
   just bst artifact log bluefin/<name>.bst  # read the build log
   just bst artifact list-contents bluefin/<name>.bst  # what was installed
   ```
3. **Enter the sandbox only after `bst show` is clean**:
   ```bash
   just bst shell --build bluefin/<name>.bst
   # replay the failing configure/build/install step interactively
   ```
4. **Delete cached failure before retrying**:
   ```bash
   just bst artifact delete bluefin/<name>.bst
   just bst build bluefin/<name>.bst
   ```
5. **Escalate to full image build only after the element is clean**:
   ```bash
   just build
   ```

### Failure class quick fixes

| Class | Typical cause | First action |
|---|---|---|
| Graph/YAML | Bad indentation, hyphenated option name, missing alias | `just bst show` to pinpoint line |
| Source fetch | Stale ref, moved URL, tarball layout change | `just bst source track` or fix alias |
| Compile | Missing build dep, `/usr/sbin` assumption | Read log, add dep or patch path |
| Install/staging | Missing `strip-binaries: ""`, overlap conflict | Set variable or add `overlap-whitelist` |
| Image composition | Not wired into `deps.bst`, or layer is `kind: stack` instead of `kind: compose` | Check `deps.bst` wiring and layer kind |

## Failure modes

- **`Error loading project` before any build output**: this is always a YAML/option error, not a build failure. Do not open a sandbox — run `just bst show` to get the exact error line.
- **Package built but missing from image**: check `deps.bst` wiring first; then check whether the downstream compose layer cache invalidated (delete artifact and rebuild).
- **Layer is silently empty**: the layer element is `kind: stack` when it must be `kind: compose`. Stack elements have zero filesystem output.

## Verification

```bash
just bst show oci/bluefin.bst          # graph is clean
just bst build bluefin/<name>.bst      # element rebuilds
just bst artifact list-contents bluefin/<name>.bst  # expected files present
```

## Related skills

- [buildstream](../buildstream/SKILL.md) — element syntax reference
- [oci-layers](../oci-layers/SKILL.md) — layer composition mechanics
- [add-package](../add-package/SKILL.md) — when the fix is a new element
