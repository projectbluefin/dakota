---
name: packaging-rust
description: Packages a Rust/Cargo project from source using generated cargo2 sources in Dakota's network-isolated BST sandbox. Load when adding or updating a Rust element.
---

# Packaging Rust Projects

## Overview

Rust elements use `kind: make` with `cargo build --release` inside BST's network-isolated sandbox. All crate dependencies are vendored via a `cargo2` source block that is **generated from `Cargo.lock` — never hand-written**. The generator script is `files/scripts/generate_cargo_sources.py`.

Reference element: `elements/bluefin/sudo-rs.bst`.

## When to use

- A Rust/Cargo project must be built from source in Dakota.
- The project does not provide suitable pre-built static binaries.

## When not to use

- Upstream ships trusted release binaries — use [packaging-binaries](../packaging-binaries/SKILL.md).
- The project is Go or Zig — use [packaging-go](../packaging-go/SKILL.md) or [packaging-zig](../packaging-zig/SKILL.md).

## Authoritative sources

- `elements/bluefin/sudo-rs.bst` — canonical Rust element template
- `files/scripts/generate_cargo_sources.py` — cargo2 source block generator
- `freedesktop-sdk.bst:components/rust.bst` — the Rust toolchain dependency

## Workflow

1. Copy the reference element:
   ```bash
   cp elements/bluefin/sudo-rs.bst elements/bluefin/<name>.bst
   ```
2. Edit the hand-authored section (first ~20 lines): update URL, track pattern, binary name, and install commands.
3. Track the source to get the latest ref:
   ```bash
   just bst source track bluefin/<name>.bst
   ```
4. Enter the build sandbox to extract `Cargo.lock`:
   ```bash
   just bst shell --build bluefin/<name>.bst
   # Inside: cat Cargo.lock > /path/on/host
   ```
5. Regenerate the cargo2 source block:
   ```bash
   python3 files/scripts/generate_cargo_sources.py path/to/Cargo.lock
   ```
6. Replace everything from the first `- kind: cargo2` line onward with the generated output.
7. Add the element to `elements/bluefin/deps.bst`.
8. Build: `just bst build bluefin/<name>.bst`.

## Failure modes

- **Hand-edited cargo2 block** — silent dependency graph corruption. Always regenerate from `Cargo.lock`.
- **Binary name collision with fdsdk** — when the Rust binary replaces a system binary (e.g. `sudo-rs` replaces `sudo`), add an `overlap-whitelist` under `public: bst:`:
  ```yaml
  public:
    bst:
      overlap-whitelist:
      - /usr/bin/sudo
  ```
- **Stale cargo2 after ref bump** — after `source track`, the `Cargo.lock` changes; you must re-run `generate_cargo_sources.py`.

## Verification

```bash
just bst build bluefin/<name>.bst
just bst shell bluefin/<name>.bst -- /usr/bin/<name> --version
```

## Related skills

- [packaging-binaries](../packaging-binaries/SKILL.md) — pre-built binary path
- [add-package](../add-package/SKILL.md) — general element addition workflow
- [buildstream](../buildstream/SKILL.md) — BST element syntax reference
