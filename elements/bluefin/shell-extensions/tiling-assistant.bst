kind: manual

sources:
- kind: git_repo
  url: github:Leleat/Tiling-Assistant.git
  track: 'v[0-9]*'
  ref: 1396caa762ae1462413a0d50bd8f8703dd1b3441

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:components/jq.bst

depends:
- freedesktop-sdk.bst:components/gettext.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    _uuid="$(jq -r .uuid "tiling-assistant@leleat-on-github/metadata.json")"
    _dest="%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}"
    install -d "${_dest}"

    cp -R tiling-assistant@leleat-on-github/* "${_dest}/"
    install -Dm644 LICENSE "${_dest}/LICENSE"
    install -Dm644 README.md "${_dest}/README.md"

    for FILE in translations/*.po; do
      [ -f "$FILE" ] || continue
      LANG=$(basename "$FILE" .po)
      install -d "${_dest}/locale/$LANG/LC_MESSAGES"
      msgfmt -c "$FILE" -o "${_dest}/locale/$LANG/LC_MESSAGES/${_uuid}.mo"
    done

    glib-compile-schemas --strict "${_dest}/schemas"

    install -Dm644 "tiling-assistant@leleat-on-github/schemas/org.gnome.shell.extensions.tiling-assistant.gschema.xml" \
      "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.tiling-assistant.gschema.xml"
  - |
    %{install-extra}
