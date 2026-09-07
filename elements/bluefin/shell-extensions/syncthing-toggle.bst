kind: manual

sources:
- kind: git_repo
  url: github:rehhouari/gnome-shell-extension-syncthing-toggle.git
  track: main
  ref: 658424caf8238b57b11e0e373aff92a7c41ecb7c

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
    sed -i "s/_('Syncthing')/_('Sync Folder')/g" toggle.js

    _uuid="$(jq -r .uuid metadata.json)"
    _dest="%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}"
    install -d "${_dest}"

    cp -R extension.js prefs.js toggle.js metadata.json icons schemas "${_dest}/"
    install -Dm644 LICENSE "${_dest}/LICENSE"
    install -Dm644 README.md "${_dest}/README.md"

    glib-compile-schemas --strict "${_dest}/schemas"

    install -Dm644 schemas/org.gnome.shell.extensions.syncthing-toggle.gschema.xml \
      "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.syncthing-toggle.gschema.xml"
  - |
    %{install-extra}
