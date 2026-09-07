kind: manual

sources:
- kind: zip
  base-dir: ""
  url: github_files:Rayzeq/quick-settings-audio-panel/releases/download/v103/quick-settings-audio-panel%40rayzeq.github.io.shell-extension.zip
  ref: 3a6da80e9b391251149bcf87a9cb5dbbccee827887d1aef43be4ee090b04a29f

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

    install -Dm644 schemas/org.gnome.shell.extensions.quick-settings-audio-panel.gschema.xml \
      "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.quick-settings-audio-panel.gschema.xml"
  - |
    %{install-extra}
