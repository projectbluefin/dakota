kind: manual

# Builds the finupdate Rust cdylib (libfinupdate.so + finupdate.h) plus the
# gnome-control-center "Updates" panel that links against it.
#
# DRAFT — outstanding work before this can build:
#  - [ ] Pin an upstream finupdate release tag (currently main); add a
#        `kind: cargo2` source block listing the vendored crate deps.
#        Generate with `bst-plugins-experimental` cargo2-helper or
#        equivalent against finupdate's Cargo.lock.
#  - [ ] Verify gtk4 / libadwaita dev headers are available in the
#        freedesktop-sdk SDK stack used here (cc-panel build pulls them
#        in transitively, but the cdylib's gtk-rs deps need them too).
#  - [ ] Wire the panel into gnome-control-center. The current dakota
#        junction patches gnome-build-meta itself, not the panels inside
#        it. Options:
#          a) Add a patch_queue patch under
#             patches/gnome-build-meta/ that drops the panel into
#             elements/core/gnome-control-center.bst's source set + edits
#             shell/cc-panel-loader.c. Cleanest but ties the panel
#             version to the gbm pin.
#          b) Override `core/gnome-control-center.bst` here (similar to
#             how `oci/integration/os-release.bst` is overridden in
#             gnome-build-meta.bst) with a sibling element that adds
#             the panel as an extra source dir + applies a small patch.
#        Approach (a) is recommended; see docs/skills/finupdate-cc-panel.md.

sources:
- kind: git_repo
  url: github:hanthor/finupdate.git
  track: main
  # TODO: pin to a tag once finupdate cuts a release
  ref: e5c393ecebbb78e833ed85407d73a7ac33a462dc

- kind: local
  path: files/finupdate-cc-panel
  directory: cc-panel-vendored

# - kind: cargo2
#   url: crates:crates
#   ref:
#   # TODO: populate from finupdate Cargo.lock

build-depends:
- freedesktop-sdk.bst:components/rust.bst
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
- freedesktop-sdk.bst:components/gtk4.bst
- freedesktop-sdk.bst:components/libadwaita.bst
- freedesktop-sdk.bst:components/pkg-config.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/gtk4.bst
- freedesktop-sdk.bst:components/libadwaita.bst

config:
  build-commands:
  - |
    # Build the cdylib + generate finupdate.h via cbindgen (driven by build.rs).
    cargo build --release --lib

  install-commands:
  - |
    install -Dm644 target/release/libfinupdate.so \
      "%{install-root}%{libdir}/libfinupdate.so"
    install -Dm644 target/release/include/finupdate.h \
      "%{install-root}%{includedir}/finupdate.h"

    # pkg-config descriptor — substitutes @prefix@ / @version@ from
    # libfinupdate.pc.in (vendored in files/finupdate-cc-panel/).
    VERSION=$(grep '^version' Cargo.toml | head -1 | cut -d'"' -f2)
    install -d "%{install-root}%{libdir}/pkgconfig"
    sed \
      -e "s|@prefix@|%{prefix}|g" \
      -e "s|@libdir@|%{libdir}|g" \
      -e "s|@includedir@|%{includedir}|g" \
      -e "s|@version@|$VERSION|g" \
      cc-panel-vendored/libfinupdate.pc.in \
      > "%{install-root}%{libdir}/pkgconfig/libfinupdate.pc"
