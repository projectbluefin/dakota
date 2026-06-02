kind: manual

sources:
- kind: local
  path: files/firstboot

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

public:
  bst:
    overlap-whitelist:
    - /usr/share/ublue-os/fastfetch.jsonc

config:
  install-commands:
  - install -Dm644 ublue-firstboot-date.service "%{install-root}/usr/lib/systemd/system/ublue-firstboot-date.service"
  - install -Dm644 bluefin-remove-installer.service "%{install-root}/usr/lib/systemd/system/bluefin-remove-installer.service"
  - install -Dm644 fastfetch.jsonc "%{install-root}/usr/share/ublue-os/fastfetch.jsonc"
  - mkdir -p "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/"
  - ln -sf ../ublue-firstboot-date.service "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/ublue-firstboot-date.service"
  - ln -sf ../bluefin-remove-installer.service "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/bluefin-remove-installer.service"
  - "%{install-extra}"
