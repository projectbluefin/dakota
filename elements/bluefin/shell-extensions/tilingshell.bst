kind: manual

sources:
- kind: zip
  url: github_files:domferr/tilingshell/releases/download/17.3/tilingshell%40ferrarodomenico.com.zip
  ref: 63ab8230b62c1a888d5af40e47aef0676e5e99ac367e35f51a797fe3b9a79370

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

    install -Dm644 schemas/org.gnome.shell.extensions.tilingshell.gschema.xml \
      "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.tilingshell.gschema.xml"
  - |
    %{install-extra}
