---

name: oci-layers
description: Explains how packages flow from BST elements into the final OCI image layer. Covers compose vs stack kinds, BST weak-key caching bug, and layer verification. Load when packages go missing from the built image or when modifying layer assembly.
metadata:
  context7-sources:
    - /apache/buildstream
---

# OCI Layers and Image Assembly

Load when understanding how packages flow into the final OCI image, modifying layer assembly, or debugging why files appear or are missing from the built image.

## When to Use

Use when a package builds but disappears from the image, when editing OCI layer assembly, or when you need to trace files from element to final image.

## When NOT to Use

- Writing individual element files → `buildstream.md`
- Debugging individual element build failures → `debugging.md`
- Understanding the CI build pipeline → `ci.md`

## Core Process

1. Trace the package from element → stack → compose layer → OCI assembly.
2. Confirm the producing element is wired into the correct dependency stack.
3. Confirm the layer stage is `compose` when filesystem output is expected.
4. Inspect built artifact contents before blaming later OCI assembly steps.
5. Re-check cache behavior if the graph is right but the image is stale.

## Assembly Architecture

```text
elements/bluefin/deps.bst           ← kind: stack (dep aggregator, no filesystem output)
  └── lists all bluefin/*.bst elements

elements/oci/layers/bluefin.bst     ← kind: compose (filters deps into /layer filesystem)
  └── depends on: deps.bst + base image
  └── compose: produces actual filesystem content under /layer

elements/oci/bluefin.bst            ← kind: script (final OCI assembly)
  └── depends on: layers/bluefin.bst + tooling
  └── runs: build-oci script to assemble the image
```

Historical path note: the `bluefin` filenames above are Dakota's OCI assembly
paths. They are not a sign to switch to the separate bluefin repo's
Containerfile-overlay workflow.

## Critical: `kind: compose` vs `kind: stack`

**This is the most common layer bug:**

```yaml
# ✅ Correct — produces filesystem content under /layer
kind: compose

# ❌ Wrong — produces ZERO filesystem output (dep aggregator only)
kind: stack
```

A layer element that is `kind: stack` will build successfully but the OCI image layer will be silently empty. Everything looks fine until you inspect the image contents.

**Verify layer type before touching `elements/oci/layers/`:**
```bash
grep "^kind:" elements/oci/layers/bluefin.bst
# Must show: kind: compose
```

## Compose Element Structure

```yaml
kind: compose
description: Dakota image layer (historical bluefin path name)
depends:
- deps.bst
- filename: freedesktop-sdk.bst:elements/base/base.bst
  junction: true

compose:
  include:
  - /usr
  - /etc
  exclude:
  - /usr/include
  - /usr/lib/debug
  - /usr/share/man
  - /usr/share/gtk-doc
```

The `compose:` block filters the staging area — only listed paths appear in `/layer`.

## OCI Script Assembly

`elements/oci/bluefin.bst` is a `kind: script` element. Key operations in order:

1. **Merge `/usr/etc` into `/etc`** — GNOME OS convention; all config goes to `/usr/etc`, must be merged for bootc
2. **Run `dconf update`** — compile dconf databases from installed keyfiles
3. **Run `ldconfig -r /layer`** — rebuild library cache after all installs
4. **Run `build-oci`** — assemble the final OCI image

**`ldconfig` must run after all installs, before `build-oci`.** Missing ldconfig causes subtle runtime library failures.

## BST Weak-Key Caching Bug

**Symptom:** A package is added to `deps.bst` and `just bst build` succeeds, but the package is missing from the final image.

**Cause:** BST's non-strict mode computes weak keys for `kind: stack` elements from direct dependency names only. Adding a new element to `deps.bst` changes the list but does not change the stack's weak key → BST considers `oci/layers/bluefin.bst` a cache hit → skips rebuild → layer has stale content.

**Workaround:**
```bash
# Force strict mode build — ignores weak key cache
just bst --no-cache-buildtrees build oci/bluefin.bst
```

**When to expect this:** After adding any new package to `deps.bst` and running a non-strict build.

## Verifying Layer Content

After a successful build, confirm your package is in the layer:
```bash
just bst artifact list-contents oci/layers/bluefin.bst | grep <package-name>
```

If the package binary is missing:
1. Confirm the element is in `deps.bst`
2. Confirm compose `include:` covers the binary path
3. Force strict rebuild: `just bst --no-cache-buildtrees build oci/bluefin.bst`

## Inspecting the Exported Image

After `just export`, the image is in podman:
```bash
sudo podman images                          # find the image name
sudo podman run --rm <image> which <binary> # check binary exists
sudo podman run --rm <image> find /usr/lib/systemd -name "<service>.service"
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The package built, so it must be in the image." | Not if it never made it through stack/compose wiring. |
| "`stack` is fine; it depends on the right things." | `stack` produces no filesystem output. |
| "Missing image content means the build failed." | It may be wiring or cache invalidation instead. |

## Red Flags

- `kind: stack` used where a layer must emit files
- Debugging OCI assembly before inspecting element artifact contents
- Assuming cache hits imply correct image contents
- Editing final OCI script when the real bug is earlier compose wiring

## Verification

- [ ] The file path was traced through element, stack, compose, and OCI assembly
- [ ] Filesystem-producing layers use `compose`
- [ ] Artifact contents were inspected before changing OCI assembly logic
- [ ] Cache behavior was considered when the graph looked correct but output was stale

## Lessons Learned

### New package in deps.bst missing from image after a successful build (2026-06-07)

This is always the BST weak-key caching bug. The package was built but the OCI layer was not rebuilt. Symptom: `just bst artifact list-contents bluefin/<name>.bst` shows files, but `just bst artifact list-contents oci/layers/bluefin.bst | grep <name>` returns nothing.

Fix — force strict-mode rebuild:
```bash
just bst --no-cache-buildtrees build oci/bluefin.bst
```

This is the only reliable fix. Do not spend time debugging the element itself; the element is fine.

### dconf update must run before ldconfig, ldconfig must run before build-oci (2026-06-07)

The OCI assembly script in `elements/oci/bluefin.bst` must run steps in this exact order:
1. Merge `/usr/etc` → `/etc`
2. `dconf update` (compile keyfiles into GVariant databases)
3. `ldconfig -r /layer` (rebuild library cache)
4. `build-oci` (assemble image)

Running `ldconfig` after `build-oci` has no effect. Running `build-oci` before `dconf update` produces an image with stale/missing dconf databases.
