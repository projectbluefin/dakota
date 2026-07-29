---
name: update-refs
description: Workflow for updating an existing package version in Dakota. Use when bumping package versions, refreshing tracked refs, or regenerating cargo2 sources after an upstream release.
---

# Update Package Refs

## Overview

Updating a Dakota package version means changing the source ref in the `.bst` element and regenerating any derived source blocks (e.g. `cargo2` for Rust). The mechanism differs by source kind — tarball elements update a `version:` variable, git-tracked elements use `bst source track`.

## When to use

- Bumping a package version or refreshing a tracked source ref
- Regenerating `cargo2` or `go_module` blocks after an upstream release

## When not to use

- Adding a new package → [add-package](../add-package/SKILL.md)
- Bumping junction refs (gnome-build-meta, freedesktop-sdk) → [patch-junctions](../patch-junctions/SKILL.md)
- Debugging a post-update build failure → [debugging](../debugging/SKILL.md)

## Authoritative sources

- `files/scripts/generate_cargo_sources.py` — cargo2 source block generator
- `.github/workflows/track-bst-sources.yml` — automated tracking matrix
- `Justfile` — `bst source track` recipe

## Workflow

1. Identify the source kind in the element (`tar`, `git_repo`, etc.).
2. Update the ref:
   - **Tarball**: edit the `version:` variable, then `just bst source track bluefin/<name>.bst`
   - **Git**: `just bst source track bluefin/<name>.bst` (updates `ref:` to latest tracked branch/tag)
3. If the element has `cargo2` sources (Rust), regenerate:
   ```bash
   just bst shell --build bluefin/<name>.bst
   # inside sandbox: cat Cargo.lock > /host/Cargo.lock
   # back on host:
   python3 files/scripts/generate_cargo_sources.py Cargo.lock
   ```
   The `cargo2` block is generated output — never hand-edit it.
4. Validate: `just bst show oci/bluefin.bst`
5. Rebuild: `just bst build bluefin/<name>.bst`

## Failure modes

- **Stale cargo2 block after git ref bump**: `bst source track` only updates `ref:` — it does not regenerate derived source blocks. A stale `cargo2` block causes "package not found in vendor directory" at build time. Always regenerate immediately after tracking a Rust element.
- **Cache masks a broken update**: a warm local cache may hide a missing crate. Delete the cached artifact (`just bst artifact delete bluefin/<name>.bst`) and rebuild from scratch to confirm correctness.

## Verification

```bash
just bst show oci/bluefin.bst          # graph validates
just bst build bluefin/<name>.bst      # element rebuilds cleanly
git diff -- elements/bluefin/<name>.bst  # only intended changes
```

## Related skills

- [packaging-rust](../packaging-rust/SKILL.md) — full Rust element lifecycle
- [patch-junctions](../patch-junctions/SKILL.md) — junction ref bumps (different workflow)
- [debugging](../debugging/SKILL.md) — when the rebuild fails
