---
name: dakota-buildstream
description: BuildStream elements, junctions, patches, dependency graphs, and build failures in Dakota. Use when editing elements, project.conf, junctions, or patches.
---

# Dakota BuildStream

Dakota builds the image from source. Never translate an RPM, DNF, COPR, or
Containerfile workflow into this repository.

## Workflow

1. Read the target element, its dependencies, and the nearest working example.
2. Inspect the graph with `just bst show --deps all <element>`.
3. Verify unfamiliar BuildStream syntax against current official documentation.
4. Make the smallest deterministic element change.
5. Run `just validate`; build the narrowest affected element when practical.
6. For patches, run `just patch-drift-check` and document the upstream status
   and removal condition in the patch itself.

## Invariants

- `kind: compose` produces layer filesystem content. `kind: stack` is only a
  dependency aggregator and produces an empty artifact.
- Add runtime dependencies to the appropriate dependency stack; do not install
  software after OCI assembly.
- Patch junction projects through a `patch_queue` source. Never modify
  `.bst/staged-junctions/`.
- Pin source tags or commits. Exclude prereleases where stable tracking requires
  it.
- Keep builds reproducible: no network calls, wall-clock timestamps, hostname,
  username, or mutable branch state in build/install commands.
- Use `mkdir -p` before creating links into a directory.
- Generated source manifests remain generated. For Cargo:

  ```bash
  python3 files/scripts/generate_cargo_sources.py path/to/Cargo.lock
  ```

## Failure triage

- Find the first failing element and first meaningful error; downstream failures
  are often consequences.
- Distinguish source fetch, sandbox/build, artifact cache, and remote-execution
  failures before editing code.
- Compare local overrides with the pinned junction version whenever a junction
  changes.
- Do not “fix” remote-execution or machine configuration by baking host-specific
  behavior into an element.

## References

- [`docs/build.md`](../../../docs/build.md)
- [`docs/patches.md`](../../../docs/patches.md)
- [`Justfile`](../../../Justfile)
- [`project.conf`](../../../project.conf)
