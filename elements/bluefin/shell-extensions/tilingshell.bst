kind: manual

sources:
- kind: zip
  base-dir: ""
  # Version 77 (pk 76684) lists GNOME 51 in metadata.json, so the GNOME 51
  # patch is dropped. Reviewed compiled extensions.gnome.org build.
  url: gnome_extensions:tilingshell@ferrarodomenico.com.shell-extension.zip?version_tag=76684
  ref: 17ab42f990d9b55f66009f50089ca172c62d206b03d0534ac5d9b63cf44e1cd1

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
    jq -e '.uuid == "tilingshell@ferrarodomenico.com" and (."shell-version" | index("51") != null)' metadata.json > /dev/null
    _uuid="$(jq -r .uuid metadata.json)"
    _dest="%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}"
    install -d "${_dest}"

    cp -R ./* "${_dest}/"

    glib-compile-schemas --strict "${_dest}/schemas"

    install -Dm644 schemas/org.gnome.shell.extensions.tilingshell.gschema.xml \
      "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.tilingshell.gschema.xml"
  - |
    %{install-extra}
