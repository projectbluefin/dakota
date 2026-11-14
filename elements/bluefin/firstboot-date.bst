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
  - install -Dm644 ublue-firstboot-date.service "%{install-root}/usr/lib/systemd/system/ublue-firstboot-date.service"
  - install -Dm644 ublue-firstboot-date.path "%{install-root}/usr/lib/systemd/system/ublue-firstboot-date.path"
  - install -Dm755 ublue-firstboot-date "%{install-root}/usr/bin/ublue-firstboot-date"
  - install -Dm644 bluefin-remove-installer.service "%{install-root}/usr/lib/systemd/system/bluefin-remove-installer.service"
  - install -Dm644 ublue-booted-image.service "%{install-root}/usr/lib/systemd/system/ublue-booted-image.service"
  - install -Dm755 ublue-booted-image-sync "%{install-root}/usr/bin/ublue-booted-image-sync"
  - mkdir -p "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/"
  - ln -sf ../ublue-firstboot-date.path "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/ublue-firstboot-date.path"
  - ln -sf ../bluefin-remove-installer.service "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/bluefin-remove-installer.service"
  - ln -sf ../ublue-booted-image.service "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/ublue-booted-image.service"
  - "%{install-extra}"
