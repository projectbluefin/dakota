kind: manual

sources:
- kind: git_repo
  url: github:projectbluefin/bluefin-bling.git
  track: main
  ref: f43fc6dccdfebe28e9312756d538208d073f7854

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
