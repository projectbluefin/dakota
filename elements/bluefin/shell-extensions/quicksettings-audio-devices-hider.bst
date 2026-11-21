kind: manual

sources:
- kind: zip
  base-dir: ""
  url: gnome_extensions:quicksettings-audio-devices-hider@marcinjahn.com.shell-extension.zip?version_tag=77569
  ref: 91cb3f43de4d865bc33417673d7baaf15844d2abca6516fbf51fec973251c26b

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

    install -Dm644 schemas/org.gnome.shell.extensions.quicksettings-audio-devices-hider.gschema.xml \
      "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.quicksettings-audio-devices-hider.gschema.xml"
  - |
    %{install-extra}
