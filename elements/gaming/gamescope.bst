# Native OGC/Valve gamescope compositor.
#
# This is the real /usr/bin/gamescope host binary used by SteamOS/Bazzite-style
# game mode. We use OpenGamingCollective's fork to match the OGC session stack
# already installed in gaming/gamescope-session*.bst. Upstream requires exact
# fallback copies of wlroots/libliftoff/vkroots, so they are vendored here as
# git modules instead of using arbitrary system versions.
kind: manual

sources:
- kind: git_repo
  url: github:OpenGamingCollective/gamescope.git
  track: ogc
  ref: 4a55229f24a9b0596ac48ee3fb60f9550203807e
- kind: git_module
  path: subprojects/wlroots
  url: github:Joshua-Ashton/wlroots.git
  ref: c08d99437ec8bb56a703f04ad1ef199502c62d10
- kind: git_module
  path: subprojects/libliftoff
  url: freedesktop:emersion/libliftoff.git
  ref: 8b08dc1c14fd019cc90ddabe34ad16596b0691f4
- kind: git_module
  path: subprojects/vkroots
  url: github:Joshua-Ashton/vkroots.git
  ref: 5106d8a0df95de66cc58dc1ea37e69c99afc9540
- kind: git_module
  path: subprojects/libdisplay-info
  url: freedesktop:emersion/libdisplay-info.git
  ref: 47a5590e9c4eb35d67651b8c05a55f1a48259329
- kind: git_module
  path: src/reshade
  url: github:Joshua-Ashton/reshade.git
  ref: 696b14cd6006ae9ca174e6164450619ace043283
- kind: git_module
  path: thirdparty/SPIRV-Headers
  url: github:KhronosGroup/SPIRV-Headers.git
  ref: d790ced752b5bfc06b6988baadef6eb2d16bdf96
- kind: git_module
  path: subprojects/glm
  url: github:g-truc/glm.git
  ref: 0af55ccecd98d4e5a8d1fad7de25ba429d60e863
- kind: git_module
  path: subprojects/stb
  url: github:nothings/stb.git
  ref: 5736b15f7ea0ffb08dd38af21067c314d6a3aae9

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/glslang.bst
- freedesktop-sdk.bst:components/pkg-config.bst
- freedesktop-sdk.bst:components/vulkan-headers.bst
- freedesktop-sdk.bst:components/wayland-protocols.bst
- freedesktop-sdk.bst:components/xwayland.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/alsa-lib.bst
- freedesktop-sdk.bst:components/hwdata.bst
- freedesktop-sdk.bst:components/libavif.bst
- freedesktop-sdk.bst:components/libcap.bst
- freedesktop-sdk.bst:components/libdecor.bst
- freedesktop-sdk.bst:components/libdrm.bst
- freedesktop-sdk.bst:components/libei.bst
- freedesktop-sdk.bst:components/libinput.bst
- freedesktop-sdk.bst:components/libseat.bst
- freedesktop-sdk.bst:components/libxkbcommon.bst
- gaming/luajit.bst
- freedesktop-sdk.bst:components/pixman.bst
- freedesktop-sdk.bst:components/pipewire.bst
- freedesktop-sdk.bst:components/sdl2-compat.bst
- freedesktop-sdk.bst:components/systemd-libs.bst
- freedesktop-sdk.bst:components/vulkan-icd-loader.bst
- freedesktop-sdk.bst:components/wayland.bst
- freedesktop-sdk.bst:components/xorg-lib-x11.bst
- freedesktop-sdk.bst:components/xorg-lib-xcb.bst
- freedesktop-sdk.bst:components/xorg-lib-xcomposite.bst
- freedesktop-sdk.bst:components/xorg-lib-xcursor.bst
- freedesktop-sdk.bst:components/xorg-lib-xdamage.bst
- freedesktop-sdk.bst:components/xorg-lib-xext.bst
- freedesktop-sdk.bst:components/xorg-lib-xfixes.bst
- freedesktop-sdk.bst:components/xorg-lib-xi.bst
- freedesktop-sdk.bst:components/xorg-lib-xrender.bst
- freedesktop-sdk.bst:components/xorg-lib-xtst.bst
- freedesktop-sdk.bst:components/xorg-lib-xxf86vm.bst
- freedesktop-sdk.bst:components/xcb-util-renderutil.bst
- freedesktop-sdk.bst:components/xcb-util-wm.bst
- gaming/xorg-lib-xmu.bst
- gaming/xorg-lib-xres.bst

variables:
  strip-binaries: ''

config:
  build-commands:
  - |
    # Meson wrap patch directories are not applied when BuildStream stages the
    # fallback projects directly, so install OGC's tiny Meson definitions for
    # header-only glm/stb ourselves.
    cp subprojects/packagefiles/glm/meson.build subprojects/glm/meson.build
    cp subprojects/packagefiles/stb/meson.build subprojects/stb/meson.build
    meson setup _build \
      --prefix=%{prefix} \
      --libdir=%{libdir} \
      --buildtype=plain \
      --wrap-mode=nodownload \
      -Denable_openvr_support=false \
      -Dbenchmark=disabled \
      -Dpipewire=enabled \
      -Ddrm_backend=enabled \
      -Dsdl2_backend=enabled \
      -Davif_screenshots=enabled \
      -Dinput_emulation=enabled
    ninja -C _build
  install-commands:
  - DESTDIR="%{install-root}" meson install -C _build --no-rebuild
  - |
    # Keep only runtime payload; static archives are not useful in the image.
    find "%{install-root}" -name '*.a' -delete
