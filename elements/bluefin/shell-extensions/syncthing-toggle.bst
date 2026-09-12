kind: manual

sources:
- kind: git_repo
  url: github:projectbluefin/bluefin-bling.git
  track: main
  ref: 67e89b215e390eb136a0fdf97bad2c0eba8b5b15

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:components/jq.bst

depends:
- bluefin/syncthing.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    cd extensions/syncthing-toggle
    _uuid="$(jq -r .uuid metadata.json)"
    _dest="%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}"
    install -d "${_dest}"

    cp -R extension.js prefs.js toggle.js metadata.json icons schemas "${_dest}/"
    install -Dm644 ../../README.md "${_dest}/README.md"

    glib-compile-schemas --strict "${_dest}/schemas"

    install -Dm644 schemas/org.gnome.shell.extensions.syncthing-toggle.gschema.xml \
      "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.syncthing-toggle.gschema.xml"
  - |
    %{install-extra}
