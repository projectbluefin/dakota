# OCI Layers and Image Assembly

Load when understanding how packages flow into the final OCI image, modifying layer assembly, or debugging why files appear or are missing from the built image.

## When NOT to Use

- Writing individual element files → `buildstream.md`
- Debugging individual element build failures → `debugging.md`
- Understanding the CI build pipeline → `ci.md`

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

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
