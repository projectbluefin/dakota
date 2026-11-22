kind: manual

sources:
- kind: git_repo
  url: github:projectbluefin/bluefin-bling.git
  track: main
  ref: 296c713880ebb8b49f01d11c99f1c54a1f73d513

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:components/jq.bst

depends:
- gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    cd extensions/power-status-color
    _uuid="$(jq -r .uuid metadata.json)"
    _dest="%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}"
    install -d "${_dest}"

    cp -R . "${_dest}/"
    install -Dm644 ../../README.md "${_dest}/README.md"
  - |
    %{install-extra}
