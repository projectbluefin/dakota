# Gaming Flatpak preinstall declarations.
#
# Steam is native in gaming/steam-native.bst. For the rest of the launcher/tool
# set we keep Dakota close to its GNOME OS base by declaring Flathub preinstalls.
# bluefin/firstboot-services.bst owns the first-boot preinstall service; this element
# only drops more *.preinstall files into /usr/share/flatpak/preinstall.d/ for
# that service to consume.
kind: manual

sources:
- kind: local
  path: files/oci/gaming-flatpak
  directory: gaming-flatpak

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
    for preinstall in gaming-flatpak/preinstall.d/*.preinstall; do
      install -Dm644 "$preinstall" "%{install-root}/usr/share/flatpak/preinstall.d/$(basename "$preinstall")"
    done
