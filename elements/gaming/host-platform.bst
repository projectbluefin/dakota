# Host-side gaming runtime support inspired by Bazzite / OpenGamingCollective.
#
# Steam is delivered as a native host launcher/bootstrap; other launchers/tools
# still come from Flathub in gaming/flatpak-apps.bst. This stack is the
# immutable host layer expected from a good gaming OS: controller udev rules,
# GameMode's system daemon, native gamescope, MangoHud/vkBasalt, InputPlumber,
# OGC gamescope-session, Vulkan discovery links, SDL/controller data,
# low-latency audio compatibility libraries, and common Wayland/X11/evdev/libusb
# glue used by native helper tools.
kind: stack

depends:
  # Performance daemon used by Steam, Lutris, Heroic, MangoHud/GOverlay, etc.
  # The daemon is host-level because apps trigger it over D-Bus.
  - freedesktop-sdk.bst:components/gamemode-daemon.bst
  - freedesktop-sdk.bst:components/libgamemode.bst

  # Native Steam launcher/bootstrap. The client self-updates into user state,
  # but the host owns /usr/bin/steam, desktop integration, bootstrap runtime,
  # and Steam's udev rules.
  - gaming/steam-native.bst

  # Native gamescope compositor for SteamOS/Bazzite-style game mode.
  - gaming/gamescope.bst

  # Native overlays/post-processing expected by Bazzite-style gaming tools and
  # OGC gamescope sessions. Flatpak games can still use runtime extensions;
  # these cover host tools, AppImages, and eventual native launchers.
  - gaming/mangohud.bst
  - gaming/vkbasalt.bst

  # Handheld/controller routing daemon used on Steam Deck/ROG Ally/Legion Go/
  # GPD/Ayaneo/OneXPlayer class devices.
  - gaming/inputplumber.bst

  # OpenGamingCollective gamescope-session scaffolding and Steam session.
  - gaming/gamescope-session-steam.bst

  # Valve's udev rules for Steam Controller, Steam Deck/Jupiter devices,
  # DualSense/DualShock, Switch Pro, Xbox receivers, and other pads Steam
  # Input needs permission to open directly. They are installed from Valve's
  # native Steam package by gaming/steam-native.bst.
  - gaming/sdl-gamecontrollerdb.bst

  # Vulkan loader/link compatibility for native host tools. Mesa/NVIDIA ICDs
  # arrive via the normal COSMIC/NVIDIA stacks; this makes discovery paths sane.
  - freedesktop-sdk.bst:components/vulkan-icd-loader.bst
  - freedesktop-sdk.bst:components/compat-vulkan-link.bst

  # Controller / input / USB helper libraries used by launchers, emulators,
  # OpenRGB-style utilities, and gamepad daemons.
  - freedesktop-sdk.bst:components/libusb.bst
  - freedesktop-sdk.bst:components/libgudev.bst
  - freedesktop-sdk.bst:components/libevdev.bst

  # SDL stack. sdl2-compat gives SDL2 ABI on top of SDL3 while SDL3 covers new
  # native apps; mixer/net/image/ttf are common runtime deps for indie titles.
  - freedesktop-sdk.bst:components/sdl3.bst
  - freedesktop-sdk.bst:components/sdl2-compat.bst
  - freedesktop-sdk.bst:components/sdl3-mixer.bst
  - freedesktop-sdk.bst:components/sdl3-net.bst
  - freedesktop-sdk.bst:components/sdl3-image.bst
  - freedesktop-sdk.bst:components/sdl3-ttf.bst

  # Audio compatibility for native games and voice chat. PipeWire is already
  # in the GNOME OS base; these provide the PulseAudio/OpenAL/ALSA plugin
  # ABIs older games and launchers dlopen.
  - freedesktop-sdk.bst:components/libpulse.bst
  - freedesktop-sdk.bst:components/openal.bst
  - freedesktop-sdk.bst:components/alsa-plugins.bst

  # Native launchers and old game binaries still probe X11/Xrandr/GLX-era libs
  # even in a Wayland session. Flatpak runtimes carry their own copies; these
  # keep host-downloaded tools and AppImages from failing immediately.
  - freedesktop-sdk.bst:components/libdecor.bst
  - freedesktop-sdk.bst:components/xorg-lib-x11.bst
  - freedesktop-sdk.bst:components/xorg-lib-xcursor.bst
  - freedesktop-sdk.bst:components/xorg-lib-xdamage.bst
  - freedesktop-sdk.bst:components/xorg-lib-xext.bst
  - freedesktop-sdk.bst:components/xorg-lib-xfixes.bst
  - freedesktop-sdk.bst:components/xorg-lib-xi.bst
  - freedesktop-sdk.bst:components/xorg-lib-xinerama.bst
  - freedesktop-sdk.bst:components/xorg-lib-xrandr.bst
  - freedesktop-sdk.bst:components/xorg-lib-xrender.bst
  - freedesktop-sdk.bst:components/xorg-lib-xscrnsaver.bst
  - freedesktop-sdk.bst:components/xorg-lib-xtst.bst
  - freedesktop-sdk.bst:components/xorg-lib-xxf86vm.bst
