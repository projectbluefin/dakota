---
name: oci-layers
description: How element output becomes the final bootc image — stack vs compose, cumulative exclude domains, the shared-base relationship between the two variants, and the post-install command order in the assembly scripts. Load when a package is missing from the built image, when editing elements/oci/, or when a successful build ships a broken system.
---

# OCI Layers and Image Assembly

## Overview

Two mechanisms decide what reaches the image, and neither one fails loudly.

Element `kind` decides whether an element emits filesystem content at all: `stack`
aggregates dependencies and produces nothing, `compose` filters staged dependencies into
an actual tree. Compose `exclude:` domains then drop split-domain content on the way
through. Both a wrong `kind` and an unintended exclusion produce a green build and a
missing file.

The assembly script that consumes the final layer is where the third class of failure
lives: its commands mutate the staged root in a fixed order, and reordering them
produces a system that only misbehaves after deployment.

## When to use

- A package builds but is missing from the exported image
- Adding, removing, or reordering anything in `elements/oci/`
- Tracing how a file reaches the image
- A build that succeeded but produced a broken or empty result

## When not to use

- Writing an individual element → [buildstream](../buildstream/SKILL.md)
- An element that fails to build → [debugging](../debugging/SKILL.md)
- Wiring a new package in end to end → [add-package](../add-package/SKILL.md)

## Authoritative sources

- `elements/oci/bluefin.bst` — the default assembly script; its inline comments carry
  the reasoning for each post-install step and are the canonical explanation
- `elements/oci/bluefin-nvidia.bst` — the nvidia assembly script
- `elements/oci/layers/` — the layer elements for both variants
- `elements/bluefin/deps.bst` — Dakota's package manifest
- `elements/bluefin-nvidia/deps.bst` — the nvidia-only additions

## Tracing the path

Read the chain from the element outward; each link is a `depends`/`build-depends` edge
you can follow in the files:

1. The element is listed in the package manifest.
2. The manifest and the junction-provided elements are aggregated by a `stack` layer,
   which also carries the `integration-commands` that rebuild the FHS layout the image
   needs.
3. A runtime `compose` layer filters that aggregate, excluding development and debug
   domains.
4. A final `compose` layer filters again with a different exclusion set.
5. The assembly script stages that final layer at `/layer` and runs its post-install
   commands over it before calling the image builder.

Exclusions are **cumulative**: content dropped by the runtime layer cannot be recovered
by the layer above it. When a file is missing, walk down this chain artifact by artifact
and find the first one that lacks it — that identifies the responsible link instead of
guessing.

## How the two variants relate

The nvidia variant is not an independent copy of the chain. Two edges tie it to the
default one, and both are visible in the element files:

- The nvidia **stack** depends on the default stack and adds `bluefin-nvidia/deps.bst`
  to it. Everything in the default package manifest therefore reaches the nvidia image
  with no nvidia-side edit, and the nvidia stack's `integration-commands` run in
  addition to the default stack's, not instead of them.
- The nvidia **assembly script** build-depends on `oci/bluefin.bst` staged at `/parent`
  and passes it to the image builder as the image `parent`. The published nvidia image
  is the default image with the nvidia layer on top.

What is genuinely duplicated per variant, and therefore the only thing that has to be
mirrored deliberately, is the content of the per-variant files above the shared stack:

- the `exclude:` domain lists in each variant's runtime and final `compose` layers
- the post-install command list in each variant's assembly script

Some differences between those files are intentional and must not be flattened into
symmetry: the nvidia script has its own sysroot seed (so the two variants do not share
machine IDs or partition UUIDs), its own labels and image reference name, and the
`parent` wiring described above.

**Nothing checks that the two chains agree.** `just validate` resolves each graph, which
proves both are well-formed; it does not compare exclusion sets or command lists between
them. There is no parity check anywhere in the repository, so a one-sided edit is caught
only by reading both files.

## Command order in the assembly script

The script's commands are a pipeline over the staged root, not an unordered list. Two
ordering rules are load-bearing:

- **Everything that mutates `/layer` runs before the linker cache is rebuilt.** The cache
  is a snapshot of the libraries present at that moment; anything installed afterwards is
  absent from it. A stale cache is invisible at build time and surfaces on a deployed
  system as a library that cannot be loaded after an upgrade bumps its version. When
  adding a post-install step, insert it before that command.
- **Image construction is last.** It packages whatever state the preceding commands left.

The element's own comments state why each individual step exists, including the
regression that motivated the linker cache rebuild. Read them there; do not copy them
into prose that will drift from the script.

The nvidia script has no linker-cache step. Its layer installs NVIDIA libraries over a
parent image whose cache was generated without them, and nothing in the nvidia chain
regenerates it. Whether any of those libraries is actually resolved through the cache
rather than through the default library search path has not been established — treat the
omission as unverified in both directions, and check the built image (below) before
either adding the step or concluding it is unnecessary.

## Failure modes

- **`kind: stack` where content was expected.** A stack staged as a layer builds fine and
  ships an empty tree. Any element whose output must appear in the image is `compose`.
- **Content lost to an exclude domain.** If an element's artifact contains the file but
  the composed layer does not, the file's split domain is in one of the exclusion lists.
  Fix the element's domain assignment rather than deleting the exclusion, which would
  pull unrelated content into the image.
- **A cached composed layer that predates the change.** Adding an element to the manifest
  can leave a previously cached layer artifact in place — the element's own artifact has
  the files, the composed layer's does not. Rebuild the assembly target strictly rather
  than concluding the wiring is wrong.
- **Editing one variant's copy of a duplicated surface.** Package additions reach both
  variants through the shared stack, but exclusion sets and post-install commands are
  per-variant files. Changing one leaves the other on the old behavior, and no check
  reports it.

## Verification

```bash
# Which layers emit content and which only aggregate
rg -n '^kind:' elements/oci/layers/*.bst

# Both graphs resolve — this is a well-formedness check, not a parity check
just validate

# The duplicated per-variant surfaces, side by side
diff elements/oci/layers/bluefin-runtime.bst elements/oci/layers/bluefin-nvidia-runtime.bst
diff elements/oci/bluefin.bst elements/oci/bluefin-nvidia.bst

# Does the composed layer actually contain the file?
just bst artifact list-contents oci/layers/bluefin.bst | rg '<binary>'

# And does the exported image?
sudo podman run --rm <image> which <binary>

# Which libraries the deployed image resolves through the linker cache
sudo podman run --rm <image> ldconfig -p | rg '<soname>'
```

## Related skills

- [add-package](../add-package/SKILL.md) — wiring a new element through this chain
- [buildstream](../buildstream/SKILL.md) — element kinds and split-domain syntax
- [debugging](../debugging/SKILL.md) — build failures rather than missing output
- [pr-review](../pr-review/SKILL.md) — reviewing changes to `elements/oci/`
