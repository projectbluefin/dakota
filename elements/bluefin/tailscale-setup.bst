kind: manual

sources:
- kind: local
  path: files/tailscale

build-depends:
- core/sandbox-tools.bst

depends:
- bluefin/tailscale.bst
- gnome-build-meta.bst:sdk/pygobject.bst
- gnome-build-meta.bst:sdk/libadwaita.bst
- freedesktop-sdk.bst:components/polkit.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm755 dakota-tailscale-setup "%{install-root}%{prefix}/libexec/dakota-tailscale-setup"
  - install -Dm755 dakota-tailscale-authorize "%{install-root}%{prefix}/libexec/dakota-tailscale-authorize"
  - install -Dm644 org.projectbluefin.dakota.TailscaleSetup.desktop "%{install-root}%{datadir}/applications/org.projectbluefin.dakota.TailscaleSetup.desktop"
  - install -Dm644 org.projectbluefin.dakota.tailscale.policy "%{install-root}%{datadir}/polkit-1/actions/org.projectbluefin.dakota.tailscale.policy"
  - "%{install-extra}"
