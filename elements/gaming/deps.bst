# Complete gaming add-on stack for the Dakota image.
#
# Goal: "GNOME OS + Bluefin + gaming" without turning Dakota into a Fedora
# package remix. The host stack provides the OS-level pieces Bazzite gets right
# (native Steam, gamescope, GameMode, controller rules/data, Vulkan discovery,
# native compatibility libs), while the app stack preinstalls non-Steam
# launchers/tools from Flathub.
kind: stack

depends:
  - gaming/host-platform.bst
  - gaming/flatpak-apps.bst
