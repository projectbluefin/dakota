# Bluefin Flatpak preinstall declarations.
#
# Declares Flathub preinstalls for the default Bluefin desktop image.
# bluefin/firstboot-services.bst owns the first-boot preinstall service; this element
# drops *.preinstall files into /usr/share/flatpak/preinstall.d/ for that service to consume.
kind: manual

sources:
- kind: local
  path: files/oci/bluefin-flatpak
  directory: bluefin-flatpak

build-depends:
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/coreutils.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    for preinstall in bluefin-flatpak/preinstall.d/*.preinstall; do
      install -Dm644 "$preinstall" "%{install-root}/usr/share/flatpak/preinstall.d/$(basename "$preinstall")"
    done
