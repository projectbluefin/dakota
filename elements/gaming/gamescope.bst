# Native OGC/Valve gamescope compositor.
#
# This is the real /usr/bin/gamescope host binary used by SteamOS/Bazzite-style
# game mode. We use OpenGamingCollective's fork to match the OGC session stack
# already installed in gaming/gamescope-session*.bst. Upstream requires exact
# fallback copies of its git submodules, so each is vendored as a git_module;
# tracking moves their refs to the tracked tag's gitlinks, but a submodule
# added, removed, or re-homed upstream needs this list edited by hand.
# subprojects/openvr is left out: the build disables OpenVR.
kind: manual

sources:
- kind: git_repo
  url: github:OpenGamingCollective/gamescope.git
  track: '[0-9]*-ogc[0-9]*'
  ref: 3.17.0-ogc1-0-g4246b87f49d6116d5f863131dcc401fc52840644
- kind: git_module
  path: subprojects/wlroots
  url: freedesktop:wlroots/wlroots.git
  ref: d783533489e1f75d6886c2ab5c5960090ef268f8
- kind: git_module
  path: subprojects/libliftoff
  url: freedesktop:emersion/libliftoff.git
  ref: 8b08dc1c14fd019cc90ddabe34ad16596b0691f4
- kind: git_module
  path: subprojects/vkroots
  url: github:Joshua-Ashton/vkroots.git
  ref: 20733b938267dcac60f6ac105dbb757f9cc8df9c
- kind: git_module
  path: subprojects/libdisplay-info
  url: freedesktop:emersion/libdisplay-info.git
  ref: c67a3e9bedb05ab61c7443704a1a107e76254595
- kind: git_module
  path: src/reshade
  url: github:Joshua-Ashton/reshade.git
  ref: 696b14cd6006ae9ca174e6164450619ace043283
- kind: git_module
  path: thirdparty/SPIRV-Headers
  url: github:KhronosGroup/SPIRV-Headers.git
  ref: d790ced752b5bfc06b6988baadef6eb2d16bdf96
# glm and stb are Meson wraps, not submodules: their revisions come from
# subprojects/{glm,stb}.wrap, which scripts/update_sources.py copies here
# after tracking.
- kind: git_repo
  url: github:g-truc/glm.git
  ref: 0af55ccecd98d4e5a8d1fad7de25ba429d60e863
  directory: subprojects/glm
- kind: git_repo
  url: github:nothings/stb.git
  ref: 5736b15f7ea0ffb08dd38af21067c314d6a3aae9
  directory: subprojects/stb

build-depends:
# gamescope src/meson.build shells out to git for its version stamp.
- freedesktop-sdk.bst:components/git.bst
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
