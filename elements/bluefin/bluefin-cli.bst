kind: manual

sources:
- kind: local
  path: files/bluefin-cli

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  # nspawn container config — hardened defaults baked in
  - install -Dm644 homebrew.nspawn "%{install-root}/etc/systemd/nspawn/homebrew.nspawn"

  # First-boot init service (runs once, pulls container image, imports as btrfs subvolume)
  - install -Dm644 bluefin-cli-init.service "%{install-root}/usr/lib/systemd/system/bluefin-cli-init.service"
  - install -d "%{install-root}/usr/lib/systemd/system/multi-user.target.wants"
  - ln -sf ../bluefin-cli-init.service "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/bluefin-cli-init.service"

  # systemd-sysupdate transfer config for container image updates
  - install -Dm644 homebrew-container.transfer "%{install-root}/usr/lib/sysupdate.bluefin-cli.d/homebrew-container.transfer"

  # Host brew wrapper — transparent CLI passthrough into the container
  - install -Dm755 brew "%{install-root}/usr/bin/brew"

  - "%{install-extra}"
