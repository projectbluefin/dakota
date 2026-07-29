# Dakota ships no VTE at all: the only things in the upstream stack that pull
# gnome-build-meta's core-deps/vte.bst -- gnome-console, gnome-builder, foundry
# -- are all dropped from this image (see core/meta-gnome-core-apps.bst), so
# the widget and, critically, its GObject-introspection typelib never reach the
# tree. GI consumers then fail to bind VTE; the ddterm Shell extension needs the
# GTK3 ABI (Vte-2.91) and cannot load. See projectbluefin/dakota#1022.
#
# Upstream core-deps/vte.bst builds GTK4-only (-Dgtk3=false). ddterm binds the
# GTK3 typelib, so this element rebuilds the identical 0.84.0 source with BOTH
# ABIs and stages the pair the image otherwise lacks:
#   Vte-2.91 + libvte-2.91.so.0        (GTK3, what ddterm needs)
#   Vte-3.91 + libvte-2.91-gtk4.so.0   (GTK4, for parity with upstream)
# The 0.84.0 source/ref MUST stay in lockstep with the gnome-build-meta
# junction's core-deps/vte.bst -- bump both together to avoid two VTE ABIs.
kind: meson

sources:
- kind: tar
  url: gnome_downloads:vte/0.84/vte-0.84.0.tar.xz
  ref: 0414e31583836aeb7878da25f67c515f7e8879917ecc37c92e26b83e8d8fc3e3

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- gnome-build-meta.bst:sdk/gobject-introspection.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/fmtlib.bst
- freedesktop-sdk.bst:components/fribidi.bst
- freedesktop-sdk.bst:components/gnutls.bst
- freedesktop-sdk.bst:components/icu.bst
- freedesktop-sdk.bst:components/systemd-libs.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:sdk/gtk.bst
# GTK3 stack is the reason this element exists: gtk3=true needs gtk+-3.0.
- gnome-build-meta.bst:sdk/gtk+-3.bst
- gnome-build-meta.bst:core-deps/fast-float.bst
- gnome-build-meta.bst:core-deps/simdutf.bst

variables:
  # docs/vapi/glade produce only devel artifacts the compose already drops, so
  # disable them to avoid pulling gi-docgen/vala just to throw the output away.
  meson-local: >-
    -Dgtk3=true
    -Dgtk4=true
    -Ddocs=false
    -Dvapi=false
    -Dglade=false

public:
  bst:
    split-rules:
      # Demo apps default to the runtime split; push them and the unversioned
      # linker symlinks (both ABIs) to devel so bluefin-runtime's compose
      # excludes them, leaving only the typelibs + versioned .so.N in the image.
      devel:
        (>):
        - '%{bindir}/vte-2.91'
        - '%{bindir}/vte-2.91-gtk4'
        - '%{datadir}/applications/org.gnome.Vte.App.Gtk3.desktop'
        - '%{datadir}/applications/org.gnome.Vte.App.Gtk4.desktop'
        # The demo apps ALSO register as xdg-terminal-exec candidates; with the
        # binaries excluded these entries would dangle, so exclude them too.
        - '%{datadir}/xdg-terminals/org.gnome.Vte.App.Gtk3.desktop'
        - '%{datadir}/xdg-terminals/org.gnome.Vte.App.Gtk4.desktop'
        # GIR XML is devel metadata; the runtime consumers load the compiled
        # typelibs. Nothing else in the image ships .gir to the standard dir.
        - '%{datadir}/gir-1.0/Vte-2.91.gir'
        - '%{datadir}/gir-1.0/Vte-3.91.gir'
        - '%{libdir}/libvte-2.91.so'
        - '%{libdir}/libvte-2.91-gtk4.so'
