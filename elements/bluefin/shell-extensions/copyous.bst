kind: manual

sources:
- kind: zip
  base-dir: ""
  url: github_files:boerdereinar/copyous/releases/download/v2.0.1/copyous%40boerdereinar.dev.zip
  ref: 7c2bfdecd66b78dc1f2491ae74e16216fca7190307411de21966da9fd47d4141

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:components/jq.bst

depends:
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    _uuid="$(jq -r .uuid metadata.json)"
    _dest="%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}"
    install -d "${_dest}"

    cp -R ./* "${_dest}/"

    glib-compile-schemas --strict "${_dest}/schemas"

    install -Dm644 schemas/org.gnome.shell.extensions.copyous.gschema.xml \
      "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.copyous.gschema.xml"
  - |
    %{install-extra}
