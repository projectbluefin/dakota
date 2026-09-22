kind: make

sources:
- kind: git_repo
  url: github:micheleg/dash-to-dock.git
  # GNOME 51 fixes (PointerWatcher and St.vertical removals) are on master
  # but unreleased; restore `track: extensions.gnome.org-v*` once a tag
  # lists "51" in metadata.json, so the tracker stops rolling back to v106.
  track: master
  ref: extensions.gnome.org-v109-0-g36529d37c0eb805b04dfd647e5295860771b23ea

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
- freedesktop-sdk.bst:components/jq.bst

depends:
- freedesktop-sdk.bst:components/gettext.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:sdk-deps/sassc.bst
- gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    _uuid="$(jq -r .uuid metadata.json)"
    %{make-install}

    # Move the schemas from /usr/share/glib-2.0 to the extension's directory and compile it there
    mkdir -p "%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}/schemas"
    mv "%{install-root}%{datadir}/glib-2.0/schemas/org.gnome.shell.extensions.dash-to-dock.gschema.xml" "%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}/schemas"
    glib-compile-schemas --strict "%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}/schemas"
  - |
    %{install-extra}
