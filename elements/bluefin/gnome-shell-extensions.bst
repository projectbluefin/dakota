kind: manual

build-depends:
  - core/sandbox-tools.bst

depends:
  # FIXME: cleanup custom make destdirs set when not needed
  - bluefin/shell-extensions/app-indicators.bst
  - bluefin/shell-extensions/bazaar-companion.bst
  - bluefin/shell-extensions/bluetooth-battery-meter.bst
  - bluefin/shell-extensions/blur-my-shell.bst
  - bluefin/shell-extensions/caffeine.bst
  - bluefin/shell-extensions/copyous.bst
  - bluefin/shell-extensions/custom-command-menu.bst
  - bluefin/shell-extensions/dash-to-dock.bst
  - bluefin/shell-extensions/fuzzy-application-search.bst
  - bluefin/shell-extensions/gradia-capture.bst
  - bluefin/shell-extensions/gsconnect.bst
  - bluefin/shell-extensions/power-status-color.bst
  - bluefin/shell-extensions/quick-settings-audio-panel.bst
  - bluefin/shell-extensions/quicksettings-audio-devices-hider.bst
  - bluefin/shell-extensions/quicksettings-audio-devices-renamer.bst
  - bluefin/shell-extensions/syncthing-toggle.bst
  - bluefin/shell-extensions/tailscale-qs.bst
  - bluefin/shell-extensions/tilingshell.bst
  # Since we use gnomeos nightly atm, no extension works with the current shell version
  - bluefin/shell-extensions/disable-ext-validator.bst

variables:
  strip-binaries: ""
