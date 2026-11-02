# Rebuild with the same Mutter as GNOME Shell. The downstream patch deliberately
# requires ABI 51: review this element when the GNOME junction changes major.
# LICENSE is installed to %{project_licensedir} automatically by BuildStream's %{install-extra}.
kind: meson

sources:
- kind: git_repo
  url: github:kancko/gnome-rounded-blur.git
  ref: f3bfcc796e1214c1e1d4287ee35cb132ad8133f0
- kind: patch
  path: patches/gnome-rounded-blur/0001-mutter-51-support.patch

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- gnome-build-meta.bst:sdk/gobject-introspection.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:core/mutter.bst

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{datadir}/gir-1.0/Blur-1.0.gir'
        - '%{libdir}/libblur-effect-1.0.so'
