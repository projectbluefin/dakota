kind: compose

# Compose the small 32-bit runtime slice native Steam needs, but expose a
# narrow split so the final filter does not install the whole i686
# freedesktop-sdk userspace over the native x86_64 image.
build-depends:
# 32-bit GLVND/GLX/EGL fixes Steam's libGL.so.1 bootstrap checks.
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/libglvnd.bst

# 32-bit X11 compatibility libraries loaded by Steam's ubuntu12_32 client.
# Without these, 32-bit steamui.so can resolve the host's 64-bit libraries and
# fail with e.g. "libXtst.so.6: wrong ELF class: ELFCLASS64".
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-x11.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xau.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xcb.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xcursor.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xdamage.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xdmcp.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xext.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xfixes.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xi.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xinerama.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xrandr.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xrender.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xscrnsaver.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xtst.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xxf86vm.bst

# 32-bit GLib stack used by Steam's 32-bit UI libraries.
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/glib.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/libffi.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:bootstrap/pcre2.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/zlib.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/util-linux.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/libeconf.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/gcc-libs.bst

# Steam's current 32-bit client packages directly link/dlopen several host
# integration libraries. Keep the selected i686 component set broad enough to
# satisfy the DT_NEEDED closure in one pass, while the split rules below still
# only export /usr/lib/i386-linux-gnu shared libraries.
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/pipewire.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/libpulse.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/openal.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/sdl3.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/sdl2-compat.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/systemd-libs.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/networkmanager.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/libdrm.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/libva.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/libvdpau.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:extensions/mesa/mesa.bst
# 32-bit Vulkan loader so 32-bit Vulkan clients (and Mesa's zink GL driver)
# can reach the 32-bit ICDs: Mesa's radv/anv below, NVIDIA's from
# bluefin-nvidia/nvidia-drivers.bst COMPAT32 rows. The loader's
# EXTRASYSCONFDIR is libdir-scoped, so the i686 build searches
# /usr/lib/i386-linux-gnu/GL/vulkan/icd.d on its own.
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/vulkan-icd-loader.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-ice.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-sm.bst
- gaming/steam-libs-i686-compat.bst

# GTK2 is still dlopened by Steam's 32-bit update UI. FDSDK no longer ships
# GTK2, so gaming/gtk2-i686.bst imports only the two legacy GTK2 shared libs
# from Debian and we compose their FDSDK-provided 32-bit dependency closure.
- gaming/gtk2-i686.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/at-spi2-core.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/brotli.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/bzip2.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/cairo.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/expat.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/fontconfig.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/freetype.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/fribidi.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/gdk-pixbuf.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/graphite2.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/harfbuzz.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/jpeg.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/libdatrie.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/libpng.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/libthai.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/libtiff.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/pango.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/pixman.bst
- freedesktop-sdk.bst:cross-compilers/freedesktop-sdk-i686.bst:components/xorg-lib-xcomposite.bst

public:
  bst:
    split-rules:
      arch:
      # Export only 32-bit shared libraries from the selected i686 components.
      # This avoids overwriting native /usr/bin tools while preventing another
      # one-library-at-a-time loop for Steam's DT_NEEDED closure.
      - "/usr/lib/i386-linux-gnu/*.so*"
      - "/usr/lib/i386-linux-gnu/pulseaudio/*.so*"

      # Mesa GL provider and the complete DRI driver stack. The hardware
      # drivers (radeonsi, iris, nouveau, ...) must ship too: exporting only
      # the software/virtio subset left 32-bit GL games (e.g. Half-Life) on
      # llvmpipe when running on metal, while VMs looked fine via virtio_gpu.
      - "/usr/lib/i386-linux-gnu/GL/default/lib/libGLX_mesa.so*"
      - "/usr/lib/i386-linux-gnu/GL/default/lib/libEGL_mesa.so*"
      - "/usr/lib/i386-linux-gnu/GL/default/lib/libEGL_indirect.so*"
      - "/usr/lib/i386-linux-gnu/GL/default/lib/libGLX_indirect.so*"
      - "/usr/lib/i386-linux-gnu/GL/default/lib/libgallium-*.so"
      - "/usr/lib/i386-linux-gnu/GL/default/lib/libgbm.so*"
      - "/usr/lib/i386-linux-gnu/GL/default/lib/libLLVM.so*"
      - "/usr/lib/i386-linux-gnu/GL/default/lib/libdrm*.so*"
      - "/usr/lib/i386-linux-gnu/GL/default/lib/dri/*.so"
      - "/usr/lib/i386-linux-gnu/GL/default/share/glvnd/**"

      # 32-bit Vulkan: Mesa ICDs (radv/anv/lvp) and their manifests. The ICD
      # JSONs live under GL/default/lib/vulkan/icd.d; GL/default/vulkan holds
      # the fdsdk-layout symlinks into lib/ and share/. GL/vulkan itself is
      # created by gaming/steam-libs-i686-compat.bst — the i686 loader's
      # EXTRASYSCONFDIR expects %{libdir}/GL/vulkan/icd.d, and unlike x86_64
      # no extension glue provides that link for the i386 tree.
      - "/usr/lib/i386-linux-gnu/GL/default/lib/libvulkan_*.so*"
      - "/usr/lib/i386-linux-gnu/GL/default/lib/vulkan/**"
      - "/usr/lib/i386-linux-gnu/GL/default/vulkan/**"
      - "/usr/lib/i386-linux-gnu/GL/default/share/vulkan/**"
      - "/usr/lib/i386-linux-gnu/GL/vulkan"

      # GLVND/GLX/EGL runtime
      - "/usr/lib/i386-linux-gnu/libEGL.so*"
      - "/usr/lib/i386-linux-gnu/libGL.so*"
      - "/usr/lib/i386-linux-gnu/libGLX.so*"
      - "/usr/lib/i386-linux-gnu/libGLdispatch.so*"
      - "/usr/lib/i386-linux-gnu/libGLESv2.so*"
      - "/usr/lib/i386-linux-gnu/libOpenGL.so*"

      # X11 runtime used by the 32-bit Steam client
      - "/usr/lib/i386-linux-gnu/libX11.so*"
      - "/usr/lib/i386-linux-gnu/libX11-xcb.so*"
      - "/usr/lib/i386-linux-gnu/libXau.so*"
      - "/usr/lib/i386-linux-gnu/libXcursor.so*"
      - "/usr/lib/i386-linux-gnu/libXdamage.so*"
      - "/usr/lib/i386-linux-gnu/libXdmcp.so*"
      - "/usr/lib/i386-linux-gnu/libXext.so*"
      - "/usr/lib/i386-linux-gnu/libXfixes.so*"
      - "/usr/lib/i386-linux-gnu/libXi.so*"
      - "/usr/lib/i386-linux-gnu/libXinerama.so*"
      - "/usr/lib/i386-linux-gnu/libXrandr.so*"
      - "/usr/lib/i386-linux-gnu/libXrender.so*"
      - "/usr/lib/i386-linux-gnu/libXss.so*"
      - "/usr/lib/i386-linux-gnu/libXtst.so*"
      - "/usr/lib/i386-linux-gnu/libXxf86vm.so*"
      - "/usr/lib/i386-linux-gnu/libxcb.so*"

      # GLib/GObject runtime and its small dependency closure
      - "/usr/lib/i386-linux-gnu/libgio-2.0.so*"
      - "/usr/lib/i386-linux-gnu/libglib-2.0.so*"
      - "/usr/lib/i386-linux-gnu/libgmodule-2.0.so*"
      - "/usr/lib/i386-linux-gnu/libgobject-2.0.so*"
      - "/usr/lib/i386-linux-gnu/libgthread-2.0.so*"
      - "/usr/lib/i386-linux-gnu/libffi.so*"
      - "/usr/lib/i386-linux-gnu/libpcre2-8.so*"
      - "/usr/lib/i386-linux-gnu/libz.so*"
      - "/usr/lib/i386-linux-gnu/libmount.so*"
      - "/usr/lib/i386-linux-gnu/libblkid.so*"
      - "/usr/lib/i386-linux-gnu/libeconf.so*"
      - "/usr/lib/i386-linux-gnu/libgcc_s.so*"
      - "/usr/lib/i386-linux-gnu/libstdc++.so*"

      # PipeWire runtime used by 32-bit steamui.so
      - "/usr/lib/i386-linux-gnu/libpipewire-0.3.so*"

      # GTK2 and graphical toolkit dependency closure
      - "/usr/lib/i386-linux-gnu/libgtk-x11-2.0.so*"
      - "/usr/lib/i386-linux-gnu/libgdk-x11-2.0.so*"
      - "/usr/lib/i386-linux-gnu/libatk-1.0.so*"
      - "/usr/lib/i386-linux-gnu/libatspi.so*"
      - "/usr/lib/i386-linux-gnu/libcairo.so*"
      - "/usr/lib/i386-linux-gnu/libcairo-gobject.so*"
      - "/usr/lib/i386-linux-gnu/libfontconfig.so*"
      - "/usr/lib/i386-linux-gnu/libfreetype.so*"
      - "/usr/lib/i386-linux-gnu/libfribidi.so*"
      - "/usr/lib/i386-linux-gnu/libgdk_pixbuf-2.0.so*"
      - "/usr/lib/i386-linux-gnu/libgraphite2.so*"
      - "/usr/lib/i386-linux-gnu/libharfbuzz.so*"
      - "/usr/lib/i386-linux-gnu/libjpeg.so*"
      - "/usr/lib/i386-linux-gnu/libdatrie.so*"
      - "/usr/lib/i386-linux-gnu/libpng16.so*"
      - "/usr/lib/i386-linux-gnu/libthai.so*"
      - "/usr/lib/i386-linux-gnu/libtiff.so*"
      - "/usr/lib/i386-linux-gnu/libpango-1.0.so*"
      - "/usr/lib/i386-linux-gnu/libpangocairo-1.0.so*"
      - "/usr/lib/i386-linux-gnu/libpangoft2-1.0.so*"
      - "/usr/lib/i386-linux-gnu/libpangoxft-1.0.so*"
      - "/usr/lib/i386-linux-gnu/libpixman-1.so*"
      - "/usr/lib/i386-linux-gnu/libXcomposite.so*"
      - "/usr/lib/i386-linux-gnu/libxcb-render.so*"
      - "/usr/lib/i386-linux-gnu/libxcb-shm.so*"
      - "/usr/lib/i386-linux-gnu/libexpat.so*"
      - "/usr/lib/i386-linux-gnu/libbz2.so*"
      - "/usr/lib/i386-linux-gnu/libbrotlidec.so*"
      - "/usr/lib/i386-linux-gnu/libbrotlicommon.so*"
