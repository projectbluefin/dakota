# Host `steam` compatibility wrapper for images where Steam is delivered as a
# Flatpak preinstall instead of a native package.
#
# OGC gamescope-session-steam, desktop files, and many helper scripts expect a
# `steam` command. Bazzite satisfies that with a native Steam RPM; this variant keeps
# Steam as Flathub state, so this tiny wrapper bridges the interface.
kind: manual

build-depends:
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/coreutils.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
# The wrapper only needs `flatpak` at runtime. Reference it through the
# junction so this
# element has no dependency outside gaming/ + freedesktop-sdk.
- freedesktop-sdk.bst:components/flatpak.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    install -Dm755 /dev/stdin "%{install-root}/usr/bin/steam" <<'EOF'
    #!/usr/bin/env sh
    exec /usr/bin/flatpak run com.valvesoftware.Steam "$@"
    EOF
