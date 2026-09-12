kind: manual

sources:
- kind: git_repo
  url: github:tailscale-qs/tailscale-gnome-qs.git
  track: 'v[0-9]*'
  ref: 7feced3f4b9bdf3ae775b203ca023ffbca2b29cb
- kind: patch
  path: patches/shell-extensions/tailscale-setup.patch

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:components/jq.bst

depends:
- bluefin/tailscale-setup.bst
- gnome-build-meta.bst:sdk/libsoup.bst
- gnome-build-meta.bst:core/gnome-shell.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    _uuid="$(jq -r .uuid "tailscale-gnome-qs@tailscale-qs.github.io/metadata.json")"
    _dest="%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}"
    install -d "${_dest}"

    cp -R tailscale-gnome-qs@tailscale-qs.github.io/* "${_dest}/"
    install -Dm644 LICENSE "${_dest}/LICENSE"
    install -Dm644 README.md "${_dest}/README.md"
  - |
    %{install-extra}
