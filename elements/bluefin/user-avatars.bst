kind: manual

# Points GNOME's avatar chooser (gnome-control-center) and gnome-initial-setup's
# account page at bluefin-common's dinosaur avatar directory. See the keyfile
# for the full explanation. Fixes: projectbluefin/dakota#353
sources:
- kind: local
  path: files/user-avatars

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm644 07-dakota-avatar-directories \
      "%{install-root}%{sysconfdir}/dconf/db/distro.d/07-dakota-avatar-directories"
  - "%{install-extra}"
