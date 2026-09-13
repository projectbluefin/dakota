# OCI Assembly — Required Post-Install Steps

`elements/oci/bluefin.bst` assembles the final bootc image from staged layers.
After all packages are installed it runs several post-install steps before
calling `build-oci`. **These steps are load-bearing — removing or reordering
them breaks the deployed image in ways that only appear after a `bootc switch`.**

## Chunkah component ownership metadata

This metadata assigns files to Chunkah components and update intervals; it is
not Unix UID/GID ownership. The local `chunkah-ownership` plugin produces only
metadata, not a composed filesystem. `oci/chunkah-metadata-tool.bst` supplies the
finalizer to the OCI assembly sandbox without installing it into the image.

`oci/chunkah/*.bst` stage the already-built corresponding compose/filter
artifact and attribute its surviving paths from the original component
manifests; they never replay integration into a second root. Production
filesystem layers remain ordinary `kind: compose` elements. The OCI scripts
check basis path/type identity, preserve known owners through later integration,
and assign `dakota.integration` only to otherwise unowned files before copying
`.dakota/ownership-final.json` beside the OCI layout. The final snapshot is read
back from the completed uncompressed OCI archive, after `build-oci` has applied
its metadata normalization, and records content, uid/gid, complete mode/mtime,
xattrs (including `security.capability`), device major/minor numbers, and hardlink
topology.

`just export` verifies the known Podman squash transition (the empty `/sys`
mountpoint), applies only the two export-time `os-release` substitutions while
preserving all other metadata, then rebinds the exact mounted root to its
immutable image ID. It writes a fakecap TSV under
`.build-ownership/<immutable-image-id>/`. `just chunkify` resolves the tag once
and uses that immutable ID for both config and mounting. It rejects a stale or
modified TSV by comparing its exact bytes with the image-bound sidecar, then
uses a private validated copy for the existing physical overlay/xattr
restoration. The sidecar is outside the OCI root and is never shipped to image
consumers. The validator uses the same privilege as Podman so root-only files
are checked; generated metadata is returned to the invoking user's ownership.

### Upstream manifest interface

Chunkah v0.6.0 supports RPM and ALPM package databases, plus xattr-based
components, but has no BuildStream or generic file-manifest backend. Dakota
therefore uses its supported xattr interface rather than inventing a package
database. The physical overlay is needed because Chunkah's raw xattr syscalls
bypass the `LD_PRELOAD` fakecap shim.

In [coreos/chunkah#113](https://github.com/coreos/chunkah/issues/113), the
maintainer proposed an input manifest for `build`, potentially paired with a
`prescan` command. The earlier
[path-prefix map](https://github.com/coreos/chunkah/pull/111) and
[exact filemap](https://github.com/coreos/chunkah/pull/112) prototypes were closed
without merging; closing those discussions did not ship a replacement interface.

Continue using the pinned xattr implementation until an upstream manifest
interface is available and validated. Revisit that interface before expanding
the delivery adapter: it could replace physical xattr restoration and its
overlay, but would not derive BuildStream ownership for us. Exact filesystem
validation is a separate Dakota design choice, not a Chunkah requirement.

### Chunkah metadata validation

The offline metadata, recipe failure-path and next-sync regression tests run
with `just check-publish-workflow` (also part of `just validate`). The explicit
export and cold-cache tests use `BST_RUNNER`, an executable checkout adapter,
without rewriting the production Justfile. The runner receives the arguments
to `just bst` unchanged and supplies its own BuildStream flags/environment.

- `just test-ownership-buildstream` exercises the companion plugin with real,
  isolated BuildStream artifacts.
- `just test-ownership-export` exercises the real export recipe with Podman and
  sudo inside a disposable container, substituting only BST checkout. It needs
  locally cached bst2 and Fedora 42 images and never changes host sudo policy.
- `just test-ownership-cold-cache DEFAULT_REF NVIDIA_REF OUTPUT_DIR` tests exact
  `project/element/64-hex-key` artifacts through a disposable local CAS server,
  an empty receiver cache and isolated export/chunkify image storage. The sender
  uses a read-only mount of `~/.cache/buildstream` with disposable overlay writes;
  the receiver cannot access that cache. No shared remote is written and no BST
  build runs. Requires a cached bst2 runner, host GCC and 80 GiB free under home;
  Chunkah may be pulled at its existing pinned digest. Only temporary resources
  are removed; logs and sidecar evidence remain in the new output directory.
  Diagnostic failures do not skip cleanup. If a temporary container cannot be
  removed, its storage is preserved and the test fails with the resource ID/path.
- `just ownership-layer-compare OLD_LAYOUT NEW_LAYOUT OUTPUT_JSON` measures
  layer reuse and new compressed bytes without publishing images. Export both
  layouts with the same compression settings; uncompressed/mixed inputs fail.

Compare migration churn (old/new ownership on the same root) separately from
steady-state updates (generated ownership across builds). Repeated exports may
change the Podman-created `/sys` directory's timestamp even with no source
changes, so layer reuse alone is not a test of source reproducibility. Transfer
estimates include new layer blobs, config and manifest, not HTTP overhead or
client-specific partial pulls.

| Step | Command | Why |
|---|---|---|
| System users | `systemd-sysusers --root /layer` | Creates system accounts (e.g. `gdm`) needed at runtime. Without this, GDM cannot start a greeter session. |
| GLib schemas | `glib-compile-schemas /layer/usr/share/glib-2.0/schemas` | Compiles dconf schema cache; missing cache breaks settings reads. |
| dconf DB | `dconf update /layer/etc/dconf/db` | Writes compiled dconf database; required for GNOME defaults. |
| **Linker cache** | **`ldconfig -r /layer`** | **Rebuilds `/etc/ld.so.cache` for the sysroot. Without this, any library SO version bump leaves the deployed system with a stale linker cache after `bootc switch`, causing `dlopen()` failures on first boot.** |

## The ldconfig rule

Every time a library with a versioned SO name is bumped (Mesa `libgallium-X.Y.Z.so`,
Pipewire `libpipewire-X.Y.so`, etc.), the linker cache in the *running* system's
`/etc/ld.so.cache` still points at the old SO name after `bootc switch`. The new
image's `/usr` has the new SO, but `/etc/ld.so.cache` is not automatically
regenerated by bootc's 3-way merge.

`ldconfig -r /layer` in the image build writes a correct cache into the image's
`/etc/ld.so.cache`. On deployment, bootc's merge adopts the image's version of
this file, so the deployed system starts with a correct cache.

**Real regression (PR #497):** The junction bump upgraded Mesa 26.0.5 → 26.0.6.
`libgallium-26.0.5.so` was replaced by `libgallium-26.0.6.so`. `dri_gbm.so` has
no RPATH and relies entirely on the linker cache. After `bootc switch`, the stale
cache caused GNOME Shell to report `Failed to open gpu '/dev/dri/card1': No such
file or directory` / `No GPUs found` on every boot — GDM looped and never showed
a login screen. Fix: `sudo ldconfig` on the affected system, and this `ldconfig
-r /layer` step in the build to prevent recurrence.

> If you are adding a new post-install step to `elements/oci/bluefin.bst`, insert
> it **before** `ldconfig -r /layer` so the linker cache reflects the final
> installed state.
