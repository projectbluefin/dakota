kind: manual

sources:
- kind: git_repo
  url: github:projectbluefin/bluefin-bling.git
  track: main
  ref: f3ed7af099a79b85f18fb5f62eb6bf208239cb0b

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
    _uuid="$(jq -r .uuid metadata.json)"
    _dest="%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}"
    install -d "${_dest}"

    cp -R extension.js metadata.json stylesheet.css "${_dest}/"
    install -Dm644 README.md "${_dest}/README.md"
  - |
    %{install-extra}
