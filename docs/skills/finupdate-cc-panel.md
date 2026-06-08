# finupdate cc-panel integration

Embeds the [finupdate](https://github.com/hanthor/finupdate) updates panel
into gnome-control-center so Dakota's Settings app gains a **Software
Updates** sidebar entry (booted image identity, "Check for updates",
changelog, switch/pin).

## Status

**Draft.** Scaffolding only — does not build yet. See the unchecked
boxes in `elements/bluefin/finupdate.bst` for the gating work.

## Shape of the integration

Three pieces have to land together:

1. **`libfinupdate` cdylib** — Rust crate built from
   `github:hanthor/finupdate` exposes the registry-probe / bootc-status
   logic over a C ABI. Produces `libfinupdate.so` + `finupdate.h` +
   `libfinupdate.pc`. Handled by `elements/bluefin/finupdate.bst`.

2. **Panel sources** — six files (`cc-updates-panel.{c,h,ui}`,
   `updates.gresource.xml`, `gnome-updates-panel.desktop.in`,
   `meson.build`) vendored in `files/finupdate-cc-panel/`. These are
   copied verbatim from the finupdate repo's `cc-panel/panels/updates/`
   directory — keep in sync when bumping the cdylib ref.

3. **gnome-control-center patch** — the panel only gets discovered if
   it's listed in `shell/cc-panel-loader.c`'s `default_panels` array
   and added to `panels/meson.build`'s `subdir()` list. Not yet
   written; see "Approach" below.

## Approach for the cc patch

`gnome-control-center` is built inside the gnome-build-meta junction
(`core/gnome-control-center.bst`). Two options:

**(a) patch_queue against gnome-build-meta.** Add a patch under
`patches/gnome-build-meta/` that:
  - drops the vendored panel sources into the gbm tree, and
  - amends `elements/core/gnome-control-center.bst` to consume them
    (extra `kind: local` source) plus a small unified diff against
    `shell/cc-panel-loader.c` and `panels/meson.build`.

Pros: matches how dakota already patches gbm (see
`patches/gnome-build-meta/disable-lorry-mirrors.patch`). One place to
look. Cons: regenerate the patch on every gbm bump.

**(b) override the element.** Replace `core/gnome-control-center.bst`
in `elements/gnome-build-meta.bst`'s `overrides:` block with a sibling
element under `elements/core/gnome-control-center.bst` that adds the
panel as an extra source dir. See `bluefin/unsigned-modules.bst` /
`oci/os-release.bst` for the override pattern.

Pros: panel changes live next to the rest of dakota. Cons: the
override has to track upstream gnome-control-center version bumps by
hand.

**Recommendation: (a).** The diff is small (~30 lines of C +
meson.build), the panel is a leaf addition that doesn't conflict with
existing cc internals, and the patch_queue regeneration burden is
lower than maintaining a parallel cc element.

## Linking

The panel's `meson.build` does `dependency('libfinupdate')`. For that
to resolve at cc build time, `libfinupdate.bst` must be a
`build-depends` of `core/gnome-control-center.bst`. The patch in (a)
needs to add that depend in the element yaml, not just the C glue.

## Runtime

`libfinupdate.so` ships in `%{libdir}` (the install rule above), so
no extra runtime hookup is needed beyond the dynamic linker finding
it. The panel itself is statically linked into the
`gnome-control-center` binary — there's no plugin discovery.

## Verification

Once built end-to-end, in a Dakota VM:

```sh
gnome-control-center updates
# → should open Settings on the new panel
```

Sidebar entry is "Software Updates" (`gnome-updates-panel.desktop.in`).

## See also

- finupdate repo: `cc-panel/README.md` — upstream integration kit.
- finupdate repo: `docs/control-center-integration.md` — design doc
  for the three paths (panel / extension / standalone app).
