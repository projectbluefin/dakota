kind: manual

sources:
- kind: local
  path: files/firstboot
- kind: local
  path: files/service-overrides

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm644 ublue-boot-timeout.service "%{install-root}/usr/lib/systemd/system/ublue-boot-timeout.service"
  - install -d "%{install-root}/usr/lib/systemd/system/multi-user.target.wants"
  - ln -sf ../ublue-boot-timeout.service "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/ublue-boot-timeout.service"
  - install -Dm644 "flatpak-preinstall.service.d/condition-check.conf" "%{install-root}/usr/lib/systemd/system/flatpak-preinstall.service.d/condition-check.conf"
  - "%{install-extra}"
