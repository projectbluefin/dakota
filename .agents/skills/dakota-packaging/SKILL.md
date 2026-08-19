---
name: dakota-packaging
description: Add, remove, or update software built from source in Dakota, including Go, Rust, Zig, binaries, and GNOME extensions.
---

# Dakota packaging

Package software as BuildStream elements. Dakota does not consume RPMs, DNF
repositories, COPRs, or Containerfile overlays.

## Add or update software

1. Find the closest element using the same build system or source type.
2. Confirm the upstream source, license, release tag, and architecture support.
3. Add an element under the narrowest appropriate subtree.
4. Add it to the dependency stack and OCI composition only where needed.
5. Track and fetch the source, then run `just validate` and build that element.
6. Inspect installed paths before expanding an OCI layer filter.

## Source rules

- Prefer source builds from pinned tags or commits.
- Prebuilt archives need per-architecture URLs and checksums/refs.
- Do not hand-write Cargo crate sources. Generate them from `Cargo.lock`:

  ```bash
  python3 files/scripts/generate_cargo_sources.py path/to/Cargo.lock
  ```

- Keep generated source blocks separate from hand-maintained build commands.
- Use upstream build systems rather than copying artifacts from a developer
  workstation.

## Language notes

- **Go:** set deterministic build flags and install the resulting binary from the
  sandbox; do not fetch modules during the build.
- **Rust:** use the generated `cargo2` source manifest and build offline.
- **Zig:** pin the supported toolchain and source release; verify target triples.
- **GNOME extensions:** package source and schemas, and verify compatibility with
  the GNOME branch Dakota currently tracks.
- **Binary releases:** validate architecture naming and install licenses alongside
  the payload.

## Removal

Trace reverse dependencies and OCI filters before deleting an element. Remove
stale references, generated metadata, patches, and service enablement together;
then run `just validate`.

## References

- [`docs/build.md`](../../../docs/build.md)
- [`docs/pr-checklist.md`](../../../docs/pr-checklist.md)
- [`elements/bluefin/`](../../../elements/bluefin/)
- [`elements/core/`](../../../elements/core/)
