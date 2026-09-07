kind: manual

sources:
- kind: zip
  url: gnome_extensions:quicksettings-audio-devices-renamer@marcinjahn.com.shell-extension.zip?version_tag=69925
  ref: a4f33897983376a23c5de69d6a008d1451afcc05cd7ce3b56630bd739c095a2e

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

    install -Dm644 schemas/org.gnome.shell.extensions.quicksettings-audio-devices-renamer.gschema.xml \
      "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.quicksettings-audio-devices-renamer.gschema.xml"
  - |
    %{install-extra}
