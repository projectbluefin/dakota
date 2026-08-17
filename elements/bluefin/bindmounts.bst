kind: manual

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

sources:
- kind: local
  path: files/bindmounts/home.mount
- kind: local
  path: files/bindmounts/root.mount
- kind: local
  path: files/bindmounts/snap.mount

config:
  install-commands:
  - |
    install -Dm644 -t '%{install-root}%{indep-libdir}/systemd/system' {home,root,snap}.mount
  - |
    install -Dm755 -d '%{install-root}%{indep-libdir}/systemd/system/local-fs.target.wants'
  - |
    ln -s ../{home,root,snap}.mount '%{install-root}%{indep-libdir}/systemd/system/local-fs.target.wants/'
