kind: manual

sources:
- kind: git_repo
  url: github:maniacx/Bluetooth-Battery-Meter.git
  track: GNOME46
  ref: 1862ef79b69756aee2297bd15a6ae6656b7c11ab

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
    _uuid="$(jq -r .uuid metadata.json)"
    _dest="%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}"
    install -d "${_dest}"

    cp -R extension.js prefs.js metadata.json stylesheet.css icons lib preferences ui script schemas "${_dest}/"
    install -Dm644 LICENSE "${_dest}/LICENSE"
    install -Dm644 README.md "${_dest}/README.md"

    for f in po/*.po; do
      [ -f "$f" ] || continue
      lang="$(basename "$f" .po)"
      install -d "${_dest}/locale/${lang}/LC_MESSAGES"
      msgfmt -c "$f" -o "${_dest}/locale/${lang}/LC_MESSAGES/${_uuid}.mo"
    done

    glib-compile-schemas --strict "${_dest}/schemas"

    install -Dm644 schemas/org.gnome.shell.extensions.Bluetooth-Battery-Meter.gschema.xml \
      "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.Bluetooth-Battery-Meter.gschema.xml"
  - |
    %{install-extra}
