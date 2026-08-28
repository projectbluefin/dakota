kind: manual

sources:
- kind: git_repo
  url: github:AlexanderVanhee/gradia-capture.git
  track: master
  ref: 9e441493a132e9f38d3a7fdf5d7f0d55a0a36369

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/jq.bst

depends:
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    _uuid="$(jq -r .uuid src/metadata.json)"
    _dest="%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}"
    install -d "${_dest}"

    cp -R src/* "${_dest}/"
    cp -R icons "${_dest}/icons"

    install -Dm644 LICENSE "${_dest}/LICENSE"
    install -Dm644 README.md "${_dest}/README.md"

    install -d "${_dest}/schemas"
    install -Dm644 schemas/org.gnome.shell.extensions.gradia-companion.gschema.xml \
      "${_dest}/schemas/org.gnome.shell.extensions.gradia-companion.gschema.xml"
    glib-compile-schemas --strict "${_dest}/schemas"
  - |
    %{install-extra}
