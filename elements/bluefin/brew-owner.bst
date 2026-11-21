kind: manual
description: |
  Homebrew prefix ownership for users who are not UID 1000. ublue-os/brew's
  brew-setup.service gives /home/linuxbrew to UID 1000 on first boot, and
  its brew-update/brew-upgrade services run as User=1000. systemd-homed
  users get UIDs from 60001, so on a homed-only system the prefix belongs
  to a UID with no user and brew is read-only for everyone.

  Ships /usr/libexec/bluefin-brew-owner and three drop-ins:
  - user@.service: before each user manager starts, give the prefix to the
    logging-in regular user if it has no owner yet (root, or a UID no user
    has). A prefix that belongs to an existing user is never touched.
  - brew-update.service, brew-upgrade.service: run brew as the prefix owner
    instead of UID 1000.
  The ublue-os/brew units themselves stay unmodified.

sources:
- kind: local
  path: files/brew-owner

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

runtime-depends:
- bluefin/brew.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 bluefin-brew-owner \
            "%{install-root}/usr/libexec/bluefin-brew-owner"
  - |
    install -Dm644 50-bluefin-brew-owner.conf \
            "%{install-root}%{indep-libdir}/systemd/system/user@.service.d/50-bluefin-brew-owner.conf"
  - |
    install -Dm644 brew-update-owner.conf \
            "%{install-root}%{indep-libdir}/systemd/system/brew-update.service.d/50-bluefin-brew-owner.conf"
  - |
    install -Dm644 brew-upgrade-owner.conf \
            "%{install-root}%{indep-libdir}/systemd/system/brew-upgrade.service.d/50-bluefin-brew-owner.conf"
