kind: make

sources:
- kind: git_repo
  url: github:aunetx/blur-my-shell.git
  track: v*
  ref: v77-0-gb1e415cc5ff3dffef72a69b552d8c64ae7d28a45

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
    # Upstream 9f45a97 (after v78) split the Makefile: plain `make` only
    # prepares build/, `make pack` writes the zip. Older tags have no pack
    # target and `make` writes the zip, so use pack when it exists.
    if make -n pack >/dev/null 2>&1; then
      %{make} pack
    else
      %{make}
    fi

    _uuid="$(jq -r .uuid metadata.json)"
    install -d "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}"
    bsdtar xvf "build/${_uuid}.shell-extension.zip" -C "%{install-root}/usr/share/gnome-shell/extensions/${_uuid}/" --no-same-owner
    glib-compile-schemas --strict "%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}/schemas"
  - |
    %{install-extra}
