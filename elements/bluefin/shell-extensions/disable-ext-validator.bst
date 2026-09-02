kind: manual

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
      enabled-extensions=['caffeine@patapon.info', 'appindicatorsupport@rgcjonas.gmail.com', 'bazaar-integration@kolunmi.github.io', 'blur-my-shell@aunetx', 'dash-to-dock@micxgx.gmail.com', 'gradia-integration@alexandervanhee.github.io', 'gsconnect@andyholmes.github.io', 'custom-command-list@storageb.github.com']

      # Disable Blur My Shell's dash-to-dock blur to prevent Clutter actor allocation race / unlock freezes
      # Fixes: https://github.com/projectbluefin/dakota/issues/1470
      [org.gnome.shell.extensions.blur-my-shell.dash-to-dock]
      blur=false
      EOF

    - "%{install-extra}"
