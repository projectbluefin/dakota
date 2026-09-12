kind: manual

sources:
- kind: git_repo
  url: github:maniacx/BudsLink-Companion.git
  track: Gnome-Extension
  ref: c11b6cf5626ee5417efc0af91148736e0697c354
- kind: patch
  path: patches/shell-extensions/budslink-companion-startup.patch

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

    cp -R extension.js prefs.js metadata.json stylesheet.css icons lib preferences ui schemas "${_dest}/"
    install -Dm644 LICENSE "${_dest}/LICENSE"
    install -Dm644 README.md "${_dest}/README.md"

    for f in po/*.po; do
      [ -f "$f" ] || continue
      lang="$(basename "$f" .po)"
      install -d "${_dest}/locale/${lang}/LC_MESSAGES"
      msgfmt -c "$f" -o "${_dest}/locale/${lang}/LC_MESSAGES/${_uuid}.mo"
    done

    glib-compile-schemas --strict "${_dest}/schemas"

    install -Dm644 schemas/org.gnome.shell.extensions.BudsLink-Companion.gschema.xml \
      "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.BudsLink-Companion.gschema.xml"
  - |
    %{install-extra}
