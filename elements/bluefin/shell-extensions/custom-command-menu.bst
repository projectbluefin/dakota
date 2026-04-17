kind: manual

sources:
- kind: git_repo
  url: github:StorageB/custom-command-menu.git
  track: main
  ref: v14-3-g8391fe24d069fb983999ad8b6439b855af73e07f
- kind: local
  path: files/dconf

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
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

    glib-compile-schemas --strict schemas/
    install -d "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}"
    cp -R ./* "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}/"

    # Install schema to system dir so gschema overrides (e.g. menuicon-setting) apply
    install -Dm644 schemas/org.gnome.shell.extensions.custom-command-list.gschema.xml \
      "%{install-root}/usr/share/glib-2.0/schemas/org.gnome.shell.extensions.custom-command-list.gschema.xml"

    # Install dconf distro keyfile with correct command* keys (fixes: projectbluefin/dakota#228)
    install -Dm644 05-dakota-custom-command-menu \
      "%{install-root}%{sysconfdir}/dconf/db/distro.d/05-dakota-custom-command-menu"
  - |
    %{install-extra}
