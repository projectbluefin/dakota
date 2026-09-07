kind: manual

build-depends:
- core/sandbox-tools.bst

depends:
  - gnome-build-meta.bst:sdk/glib.bst
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
    - mkdir -p "%{install-root}%{datadir}/glib-2.0/schemas/"
    - |
      cat <<EOF > "%{install-root}%{datadir}/glib-2.0/schemas/zz3-bluefin-unsupported-stuff.gschema.override"
      [org.gnome.shell]
      disable-extension-version-validation=true
      enabled-extensions=['caffeine@patapon.info', 'appindicatorsupport@rgcjonas.gmail.com', 'bazaar-integration@kolunmi.github.io', 'blur-my-shell@aunetx', 'dash-to-dock@micxgx.gmail.com', 'gradia-integration@alexandervanhee.github.io', 'gsconnect@andyholmes.github.io', 'custom-command-list@storageb.github.com', 'Bluetooth-Battery-Meter@maniacx.github.com', 'copyous@boerdereinar.dev', 'power-status-color@local', 'quicksettings-audio-devices-hider@marcinjahn.com', 'quicksettings-audio-devices-renamer@marcinjahn.com', 'syncthing-toggle@rehhouari.github.com', 'tailscale-gnome-qs@tailscale-qs.github.io', 'tilingshell@ferrarodomenico.com']

      [org.gnome.shell.extensions.Bluetooth-Battery-Meter]
      level-indicator-color=0

      [org.gnome.shell.extensions.syncthing-toggle]
      start-stop-only=true

      [org.gnome.shell.extensions.tilingshell]
      show-indicator=false
      EOF

    - "%{install-extra}"
