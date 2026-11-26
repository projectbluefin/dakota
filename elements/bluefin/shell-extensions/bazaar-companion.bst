kind: manual

sources:
- kind: git_repo
  url: github:bazaar-org/bazaar-companion.git
  track: main
  ref: 0d3af1137b1b2407499c72d1e7aecc528eebccf5

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
    _uuid="$(jq -r .uuid src/metadata.json)"
    install -d "%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}"
    cp -R src/* "%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}/"
  - |
    %{install-extra}
