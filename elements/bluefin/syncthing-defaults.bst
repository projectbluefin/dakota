# Syncthing 2 removed the automatic default folder, so the image supplies one.
# Static data only: no scripts, no logic, no identity. Keys and the device ID
# are generated on first run. Sharing a folder with a peer remains an explicit
# action; the stable ids mean an offered folder maps onto the matching local
# folder instead of arriving as a duplicate. `path` is local-only and is never
# sent to peers, so a differently-named home directory still pairs correctly.
#
# The config ships through /etc/skel so it reaches new accounts only, matching
# the scope of the XDG directories beside it. Its mode is then applied by a
# user-tmpfiles `z` rule: BuildStream stores artifacts in CAS, which records
# only an executable bit, so an `install -m600` here would reach the image as
# 0644 — and Syncthing keeps a config's existing mode when it rewrites the file
# (verified against v2.1.5: `serve` on this config rewrites nothing at all, and
# a `generate` rewrite that added the apikey and device identity kept 0600).
kind: manual

sources:
- kind: local
  path: files/syncthing-defaults

build-depends:
- core/sandbox-tools.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm644 config.xml "%{install-root}/etc/skel/.local/state/syncthing/config.xml"
  - install -Dm644 syncthing-defaults.conf "%{install-root}%{datadir}/user-tmpfiles.d/50-dakota-syncthing.conf"
  # xdg-user-dirs-update reassigns a configured directory to $HOME when it is
  # missing, which would point Syncthing at the whole home directory including
  # its own key.pem. Ship the untranslated names and the directories together
  # so that cannot happen in any locale.
  - install -Dm644 user-dirs.dirs "%{install-root}/etc/skel/.config/user-dirs.dirs"
  - |
    for _dir in Documents Music Pictures Videos; do
      install -d "%{install-root}/etc/skel/${_dir}"
    done
  - "%{install-extra}"
