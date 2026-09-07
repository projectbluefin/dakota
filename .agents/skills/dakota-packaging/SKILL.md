---
name: dakota-packaging
description: Add, remove, or update native software built from source in Dakota, including Go, Rust, Zig, C/Meson, and binary releases.
metadata:
  context7-sources:
    - /apache/buildstream
---

# Dakota Packaging

Package software as BuildStream elements. Dakota builds natively from source and does not consume RPMs, DNF repositories, COPRs, or Containerfile overlays.

## When to Use

- Adding a new native CLI tool, service, or library to Dakota
- Updating an existing package element under `elements/bluefin/` or `elements/core/`
- Generating offline crate sources for Rust programs
- Removing deprecated software and cleaning up dependency stacks

## When NOT to Use

- Packaging GNOME Shell extensions → load `dakota-extensions`
- Host Homebrew integration or formulas → load `dakota-workstation`
- Layer composition in `elements/oci/layers/` → load `dakota-image`
- ujust user commands → load `dakota-ujust`

## Core Process

1. **Locate Reference Pattern**: Identify an existing element with the same toolchain (Go, Rust, Zig, Meson, CMake, Autotools, or binary).
2. **Verify Upstream**: Confirm upstream source, open-source license, release tag, and multi-arch support (`x86_64` and `aarch64`).
3. **Declare Element**: Create `elements/bluefin/<name>.bst` or under the appropriate subdirectory.
4. **Wire Dependencies**: Wire into `elements/bluefin/deps.bst` (the aggregator stack) or the relevant layer composition element.
5. **Generate Offline Sources (Rust)**:
   ```bash
   python3 files/scripts/generate_cargo_sources.py path/to/Cargo.lock
   ```
6. **Validate and Build**:
   ```bash
   just validate
   just bst build bluefin/<name>.bst
   ```
7. **Inspect Output**: Check installed paths and permissions inside the artifact before expanding layer filters.

## Language Invariants

- **Go**: Use `go build` with flags ensuring deterministic, offline compilation (`-buildvcs=false`, `-trimpath`). Statically or dynamically link as appropriate. Do not run `go get` or `go install` across the network.
- **Rust**: Never hand-craft crate lists. Always use `files/scripts/generate_cargo_sources.py` from `Cargo.lock` to generate `kind: cargo2` source blocks. Build with `cargo --frozen --offline`.
- **Zig**: Pin the exact toolchain version; specify the target triple explicitly.
- **C/Meson/Autotools**: Inherit build dependencies from junctions (`freedesktop-sdk.bst:components/...`). Do not install unpinned dependencies.
- **Binary Releases**: Require per-architecture URLs, SHA256 checksums, and license installation to `%{install-root}%{datadir}/licenses/<package>/`.

## Package Removal Hygiene

When deleting a package:
1. Trace reverse dependencies with `just bst show --deps all oci/bluefin.bst | grep <element>`.
2. Remove entry from `elements/bluefin/deps.bst` and layer compose elements.
3. Delete static files, systemd unit symlinks, and any patches in `patches/`.
4. Run `just validate` to confirm the graph is sound.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I can quickly fetch this dependency during build." | Sandboxes lack network access. All assets must be declared in element sources. |
| "Writing Cargo sources by hand is faster for small crates." | Hand-rolled Cargo blocks miss sub-dependencies and checksums. Always use `generate_cargo_sources.py`. |
| "A binary release doesn't need license files." | Legal distribution requires licenses packaged alongside binaries. |

## Red Flags

- Network calls (`curl`, `wget`, `git clone`) inside `install-commands`
- Hand-maintained Cargo source blocks without `generate_cargo_sources.py`
- Storing pre-compiled binaries in git instead of downloading release archives via sources
- Unpinned git tracking branches (`track: main` without a pinned `ref:`)

## Verification

- [ ] `just validate` passes
- [ ] Element builds cleanly via `just bst build bluefin/<name>.bst`
- [ ] No network access is attempted during sandbox compilation
- [ ] Installed binaries, configs, and licenses land in standard `/usr` hierarchy
- [ ] Element is added to `elements/bluefin/deps.bst`

## References

- [`docs/build.md`](../../../docs/build.md)
- [`docs/pr-checklist.md`](../../../docs/pr-checklist.md)
- [`elements/bluefin/`](../../../elements/bluefin/)
- [`elements/core/`](../../../elements/core/)
