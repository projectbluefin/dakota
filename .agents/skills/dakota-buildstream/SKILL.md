---
name: dakota-buildstream
description: BuildStream elements, junctions, patches, dependency graphs, and build failures in Dakota. Use when editing elements, project.conf, junctions, or patches.
metadata:
  context7-sources:
    - /apache/buildstream
---

# Dakota BuildStream

Dakota builds the bootc desktop image entirely from source using BuildStream 2.
Never translate RPM, DNF, COPR, or Containerfile workflows into this repository.

## When to Use

- Creating, editing, or removing `.bst` elements in `elements/`
- Modifying `project.conf` or junction configurations (`elements/gnome-build-meta.bst`, `elements/freedesktop-sdk.bst`)
- Managing downstream patches in `patches/`
- Triaging build, sandbox, or artifact cache failures in local runs or CI

## When NOT to Use

- Workstation Homebrew integration → load `dakota-workstation`
- End-user ujust recipes → load `dakota-ujust`
- GNOME Shell extensions packaging → load `dakota-extensions`
- Image layer composition and boot verification → load `dakota-image`

## Core Process

1. **Inspect Graph**: Run `just bst show --deps all <element>` to trace dependencies and dependents.
2. **Consult Nearest Pattern**: Check elements with similar build systems (`manual`, `autotools`, `meson`, `cmake`).
3. **Verify Syntax**: Check syntax against official BuildStream documentation (`/apache/buildstream`).
4. **Implement Deterministically**: Ensure build/install steps are reproducible (no network, timestamps, or host identity).
5. **Validate Graph**: Run `just validate`. For element-specific tests, build the narrowest target (`just bst build <element>`).
6. **Patch Hygiene**: For junction patches, update `patches/`, verify with `just patch-drift-check`, and set `Upstream-Status:` headers.

## Invariants

- **Compose vs Stack**: `kind: compose` generates layer filesystem artifacts. `kind: stack` only aggregates dependencies and outputs zero filesystem files.
- **No Post-Install Packaging**: All runtime software must be integrated via BST elements before OCI composition.
- **Junction Patches**: Patch junctions via `kind: patch_queue` sources. Never modify `.bst/staged-junctions/`.
- **Source Pinning**: Pin git sources to commit SHAs or release tags. Never track mutable branches in production elements.
- **Reproducibility**: No network calls, `$(date)`, `$(hostname)`, `whoami`, or random seeds in build commands.
- **Directory Creation**: Run `mkdir -p` before creating links or writing files into target directories.
- **Generated Cargo Sources**: Generate crate manifests via:
  ```bash
  python3 files/scripts/generate_cargo_sources.py path/to/Cargo.lock
  ```
- **Out-of-Tree Kernel Modules**: Build against `/usr/lib/modules/$KVER/build` provided by `freedesktop-sdk.bst:components/linux.bst`. Defer `depmod` from the driver element's `install-commands` to the composed layer stack's `integration-commands` (`depmod -a "$KVER"`).

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I can install this package with DNF in a container step." | Dakota has no DNF or RPM database. All packages are BST elements. |
| "A `kind: stack` element will put its files into the image layer." | Stack elements produce empty artifacts. Layers require `kind: compose`. |
| "I'll fetch dependencies during `install-commands`." | Sandboxes lack network access during build. All sources must be declared in `sources:`. |
| "I'll patch the staged junction file directly in `.bst/`." | Staged junction edits are wiped on cache cleans. Use `patches/` with `patch_queue`. |

## Red Flags

- `rpm-ostree`, `dnf`, `apt`, or `pip install` inside build instructions
- Using `kind: stack` inside `elements/oci/layers/`
- `ref:` pointing to a branch name instead of a git commit or tag
- Using `$(date)` or `$(hostname)` in install commands
- Adding patches without an `Upstream-Status:` header and exit condition

## Verification

- [ ] `just validate` passes without errors
- [ ] `just bst show --deps all <element>` resolves cleanly
- [ ] Narrowest element builds in isolation via `just bst build <element>`
- [ ] `just patch-drift-check` passes if junction patches were touched
- [ ] Commit message follows `<type>(<scope>): <desc>` with `Assisted-by:` trailer

## References

- [`docs/build.md`](../../../docs/build.md)
- [`docs/patches.md`](../../../docs/patches.md)
- [`Justfile`](../../../Justfile)
- [`project.conf`](../../../project.conf)
