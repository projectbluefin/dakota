kind: manual

sources:
- kind: git_repo
  url: github:projectbluefin/bluefin-bling.git
  track: main
  ref: d58a5281b7f249da33cac531365989ed0db7569a

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:components/jq.bst

runtime-depends:
- bluefin/uutils-coreutils.bst
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:components/podman.bst
- freedesktop-sdk.bst:components/xdg-user-dirs.bst
- gnome-build-meta.bst:sdk/gjs.bst
- gnome-build-meta.bst:sdk/libsoup.bst

depends:
# Retain the native unit for safe migration of existing, stopped services.
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

    cp -R . "${_dest}/"
    install -Dm644 ../../README.md "${_dest}/README.md"

    glib-compile-schemas --strict "${_dest}/schemas"

    install -Dm644 schemas/org.gnome.shell.extensions.syncthing-toggle.gschema.xml \
      "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.syncthing-toggle.gschema.xml"
  - |
    %{install-extra}
