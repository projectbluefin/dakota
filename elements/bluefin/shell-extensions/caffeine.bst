kind: make

sources:
- kind: git_repo
  url: github:eonpatapon/gnome-shell-extension-caffeine.git
  track: v*
  ref: v61-0-g0c35fdf997d2ffaa34f90b2cae7695b9014bc59c

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
  build-commands:
  - |
    %{make} build
  install-commands:
  - |
    _uuid="$(jq -r .uuid "caffeine@patapon.info/metadata.json")"
    install -d "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}"
    bsdtar xvf "${_uuid}.zip" \
      -C "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}/" \
      --no-same-owner
    if [ -d "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}/schemas" ]; then
      glib-compile-schemas --strict \
        "%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}/schemas"
    fi
  - |
    %{install-extra}
