# Rebuild with the same Mutter as GNOME Shell. The downstream patch deliberately
# requires ABI 51: review this element when the GNOME junction changes major.
# LICENSE is installed to %{project_licensedir} automatically by BuildStream's %{install-extra}.
kind: meson

sources:
- kind: git_repo
  url: github:kancko/gnome-rounded-blur.git
  track: 'v*'
  ref: v1.0.2-0-ga4db9e5947b1cea0a05c57768356921420f91293
- kind: patch
  path: patches/gnome-rounded-blur/0001-bind-detected-mutter.patch

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
