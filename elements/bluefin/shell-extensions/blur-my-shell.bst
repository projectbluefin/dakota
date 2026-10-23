kind: make

sources:
- kind: git_repo
  url: github:aunetx/blur-my-shell.git
  track: v*
  ref: v76-0-g19ce844b8ca36efe4a181b2cf81504063eb4ce4b

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
- freedesktop-sdk.bst:components/jq.bst

depends:
- freedesktop-sdk.bst:components/gettext.bst
- gnome-build-meta.bst:sdk/glib.bst
- gnome-build-meta.bst:core/gnome-shell.bst

runtime-depends:
- bluefin/gnome-rounded-blur.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    %{make}

    _uuid="$(jq -r .uuid metadata.json)"
    install -d "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}"
    bsdtar xvf "build/${_uuid}.shell-extension.zip" -C "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}/" --no-same-owner
    glib-compile-schemas --strict "%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}/schemas"
  - |
    %{install-extra}
