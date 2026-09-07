kind: manual

sources:
- kind: git_repo
  url: codeberg:mkhl/gnome-shell-extension-fuzzy-application-search.git
  track: v2
  ref: 864bf0ca6a3963e93cde7d5fd4fba8fb37cf0f49

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
