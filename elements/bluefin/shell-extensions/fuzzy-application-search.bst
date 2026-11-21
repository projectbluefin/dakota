kind: manual

sources:
- kind: git_repo
  url: codeberg:mkhl/gnome-shell-extension-fuzzy-application-search.git
  track: 'v[0-9]*'
  ref: v3-0-g6f8185b86963dfba89028f814c8c4af0e327fc6a

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

    install -Dm644 extension.js "${_dest}/extension.js"
    install -Dm644 scoring.js "${_dest}/scoring.js"
    install -Dm644 metadata.json "${_dest}/metadata.json"
    install -Dm644 LICENSE "${_dest}/LICENSE"
    install -Dm644 README.md "${_dest}/README.md"
  - |
    %{install-extra}
