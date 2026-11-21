kind: manual
description: |
  systemd-homed defaults. Pins DefaultStorage=subvolume so every new homed
  user gets a Btrfs subvolume home, whatever the installer's disk
  encryption choice was.

  Without it homed picks the storage on its own: LUKS when /home is not
  encrypted, subvolume when it is. A LUKS home on Dakota's single shared
  Btrfs /var reserves ~83% of the free space while the user is logged in
  (no online discard, auto-resize, then a rebalance that switches itself
  off after the first run), which starves bootc, flatpak, podman and
  journald, and can lock the user out at GDM with no error message once
  the OS has used that space. A subvolume home shares space with the OS
  like a classic home does.

  Only the default changes. An explicit `homectl create --storage=...`
  still wins, and existing homes keep their storage.

build-depends:
- core/sandbox-tools.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    install -d "%{install-root}%{indep-libdir}/systemd/homed.conf.d"
    cat > "%{install-root}%{indep-libdir}/systemd/homed.conf.d/10-bluefin.conf" <<'EOF'
    # Bluefin: new homed users get a Btrfs subvolume home, independent of
    # whether /home is encrypted (homed's automatic choice). Override in
    # /etc/systemd/homed.conf.d/ or per user with homectl --storage=.
    [Home]
    DefaultStorage=subvolume
    EOF
