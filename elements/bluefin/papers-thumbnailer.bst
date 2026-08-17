kind: manual

build-depends:
- core/sandbox-tools.bst
- gnome-build-meta.bst:core/papers.bst

depends:
- freedesktop-sdk.bst:components/lcms.bst
- freedesktop-sdk.bst:components/libseccomp.bst
- freedesktop-sdk.bst:components/poppler.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- gnome-build-meta.bst:core-deps/exempi.bst
- gnome-build-meta.bst:core-deps/libspelling.bst
- gnome-build-meta.bst:sdk/adwaita-icon-theme.bst
- gnome-build-meta.bst:sdk/cairo.bst
- gnome-build-meta.bst:sdk/gdk-pixbuf.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:sdk/gtk.bst
- gnome-build-meta.bst:sdk/libadwaita.bst
- gnome-build-meta.bst:sdk/libsecret.bst
- gnome-build-meta.bst:sdk/pango.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 \
      "%{bindir}/papers-thumbnailer" \
      "%{install-root}%{bindir}/papers-thumbnailer"

    install -Dm644 \
      "%{datadir}/thumbnailers/papers.thumbnailer" \
      "%{install-root}%{datadir}/thumbnailers/papers.thumbnailer"

    install -Dm644 \
      "%{mandir}/man1/papers-thumbnailer.1" \
      "%{install-root}%{mandir}/man1/papers-thumbnailer.1"

    mkdir -p \
      "%{install-root}%{libdir}" \
      "%{install-root}%{libdir}/papers/6/backends" \
      "%{install-root}%{datadir}/metainfo"

    cp -a "%{libdir}"/libppsdocument-4.0.so* "%{install-root}%{libdir}/"
    cp -a "%{libdir}"/libppsview-4.0.so* "%{install-root}%{libdir}/"
    cp -a "%{libdir}/papers/6/backends"/libpdfdocument.so "%{install-root}%{libdir}/papers/6/backends/"
    cp -a "%{libdir}/papers/6/backends"/org.gnome.Papers.PdfDocument.papers-backend "%{install-root}%{libdir}/papers/6/backends/"
    cp -a "%{datadir}/metainfo"/org.gnome.Papers.PdfDocument.metainfo.xml "%{install-root}%{datadir}/metainfo/"
