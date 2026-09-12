kind: manual

sources:
- kind: zip
  base-dir: ""
  # Reviewed 17.3 build with GNOME 50 support, not the older GitHub ZIP.
  url: gnome_extensions:tilingshell@ferrarodomenico.com.shell-extension.zip?version_tag=70233
  ref: 0a9f2b26de65294f53350d74089a3dae9376642784a722e98fc8d78fcc470a35

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
    # Fail the package build rather than relying on disabled Shell validation.
    jq -e '.uuid == "tilingshell@ferrarodomenico.com" and (."shell-version" | index("50") != null)' metadata.json > /dev/null
    _uuid="$(jq -r .uuid metadata.json)"
    _dest="%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}"
    install -d "${_dest}"

    cp -R ./* "${_dest}/"

    glib-compile-schemas --strict "${_dest}/schemas"

    install -Dm644 schemas/org.gnome.shell.extensions.tilingshell.gschema.xml \
      "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.tilingshell.gschema.xml"
  - |
    %{install-extra}
