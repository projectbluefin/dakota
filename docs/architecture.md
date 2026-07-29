# Dakota architecture

Dakota is a **from-source bootc image** assembled with BuildStream and published as an OCI image.

This page describes the durable boundaries. For mutable implementation details, read the owning element, workflow, or Just recipe.

## Core model

- **Build system:** [BuildStream 2](https://buildstream.build/) project rooted at [`project.conf`](../project.conf)
- **Imported upstreams:** junction elements such as [`elements/freedesktop-sdk.bst`](../elements/freedesktop-sdk.bst) and [`elements/gnome-build-meta.bst`](../elements/gnome-build-meta.bst)
- **Dakota-specific content:** [`elements/bluefin/`](../elements/bluefin), [`files/`](../files), and [`patches/`](../patches)
- **Image assembly:** [`elements/oci/layers/`](../elements/oci/layers) plus the final script element [`elements/oci/bluefin.bst`](../elements/oci/bluefin.bst)
- **Runtime:** bootc + composefs, not a mutable RPM-managed host

BuildStream's project and junction model is the right mental model here: projects declare `.bst` elements locally and pull in external projects through junction elements rather than by vendoring build logic inline.

## Repository boundaries

### 1. BuildStream, not image patching

Dakota is built from elements and source refs. Do not treat the repo as a Dockerfile or RPM overlay project.

Authoritative sources:
- [`project.conf`](../project.conf)
- [`elements/`](../elements)
- [`Justfile`](../Justfile)

### 2. Shared base layer versus Dakota-specific changes

Dakota consumes `projectbluefin/common` as a base layer, then adds or removes Dakota-specific content.

The durable boundary is:
- **shared content** belongs in the `common` source consumed by [`elements/bluefin/common.bst`](../elements/bluefin/common.bst)
- **Dakota-only stripping, overrides, and packaging** belong in this repo

If a shared file from common does not belong in a fresh Dakota install, remove it in the `install-commands` for [`elements/bluefin/common.bst`](../elements/bluefin/common.bst) instead of pretending Dakota owns the upstream shared source tree.

### 3. Layer assembly is explicit

Dakota's final image is not one giant package install. The assembly chain is:

1. package and integration elements populate Dakota-specific filesystem content
2. OCI layer elements in [`elements/oci/layers/`](../elements/oci/layers) compose the filesystem view
3. [`elements/oci/bluefin.bst`](../elements/oci/bluefin.bst) performs post-processing and writes the final OCI image

The final assembly step is where boot/runtime-sensitive post-processing lives, such as `systemd-sysusers`, schema compilation, dconf database generation, and linker-cache generation.

### 4. Composefs runtime matters

Dakota ships as a bootc image and runs with composefs-oriented assumptions.

That means:
- do not recommend `rpm-ostree` or mutable-host repair flows as the default Dakota model
- evaluate publish/export choices against the composefs runtime, not only against what an OCI tool accepts
- treat boot validation as a first-class correctness check for runtime-affecting changes

## Patches and upstream boundaries

Patch queues are maintenance debt and should stay scoped to the imported project they modify.

Authoritative sources:
- [`patches/`](../patches)
- junction elements under [`elements/`](../elements)
- [`just patch-drift-check`](../Justfile)

When a fix is available upstream, prefer moving the junction ref and deleting the downstream patch over growing a permanent local patch queue.

## Source of truth map

| Topic | Read this doc for context | Read this file for current truth |
|---|---|---|
| Local command surface | this page | [`Justfile`](../Justfile) |
| Build graph and sources | this page | [`project.conf`](../project.conf), [`elements/`](../elements) |
| Shared-layer adjustments | this page | [`elements/bluefin/common.bst`](../elements/bluefin/common.bst) |
| Final image assembly | this page | [`elements/oci/bluefin.bst`](../elements/oci/bluefin.bst) |
| Validation expectations | [`docs/qa.md`](qa.md) | [`Justfile`](../Justfile), CI workflows |
| Promotion and trust | [`docs/release.md`](release.md) | publish / release / rollback workflows |
