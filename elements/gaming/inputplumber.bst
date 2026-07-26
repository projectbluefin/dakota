# InputPlumber handheld/controller routing daemon.
#
# Bazzite's handheld images rely on InputPlumber for built-in controller,
# gyro/IMU, and special-button routing on Steam Deck / ROG Ally / Legion Go /
# GPD / Ayaneo / OneXPlayer style devices. Upstream publishes a self-contained
# usr/ payload; we install that and provide libiio separately.
kind: manual

sources:
- kind: tar
  url: github-releases:ShadowBlip/InputPlumber/releases/download/v0.77.2/inputplumber-x86_64.tar.gz
  ref: 4494e014bfc737d01c900be2160290a12215b97536a5070bf98387cd933e7b23

build-depends:
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/coreutils.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/systemd.bst
- freedesktop-sdk.bst:components/dbus.bst
- freedesktop-sdk.bst:components/libgudev.bst
- gaming/libiio.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - mkdir -p "%{install-root}/usr"
  - cp -a usr/. "%{install-root}/usr/"
  # Enable the daemon and its suspend hook by default. InputPlumber also ships
  # udev autostart rules, but enabling the service makes handheld support work
  # even when devices enumerate before udev catches up.
  - |
    install -Dm644 /dev/stdin "%{install-root}/usr/lib/systemd/system-preset/92-gaming-inputplumber.preset" <<'EOF'
    enable inputplumber.service
    enable inputplumber-suspend.service
    EOF
