# Public gaming stack: host-level runtime support only.
#
# Downstreams that want to choose their own app delivery can depend on this for
# native Steam/gamescope, GameMode, controller rules/data, Vulkan discovery,
# SDL/audio/input helper libraries, etc. without inheriting Dakota's non-Steam
# Flathub preinstall choices.
kind: stack

depends:
  - gaming/host-platform.bst
