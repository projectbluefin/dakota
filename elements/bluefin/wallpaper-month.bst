kind: manual

sources:
- kind: local
  path: files/firstboot

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm644 ublue-wallpaper-month.service "%{install-root}/usr/lib/systemd/system/ublue-wallpaper-month.service"
  - install -d "%{install-root}/usr/lib/systemd/system/multi-user.target.wants"
  - ln -sf ../ublue-wallpaper-month.service "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/ublue-wallpaper-month.service"
  - "%{install-extra}"
