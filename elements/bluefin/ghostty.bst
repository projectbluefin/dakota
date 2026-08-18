kind: manual

variables:
  strip-binaries: ""

build-depends:
  - core/sandbox-tools.bst
  - bluefin/zig.bst
  - freedesktop-sdk.bst:components/tar.bst
  - freedesktop-sdk.bst:components/gzip.bst
  - freedesktop-sdk.bst:components/gettext.bst
  - freedesktop-sdk.bst:components/pkg-config.bst

depends:
  - gnome-build-meta.bst:sdk/gtk.bst
  - gnome-build-meta.bst:sdk/libadwaita.bst
  - bluefin/gtk4-layer-shell.bst
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

sources:
  # Ghostty source tarball
  - kind: tar
    url: ghostty_releases:1.3.1/ghostty-1.3.1.tar.gz
    ref: 3349d25600ffbda281197a18314f7d18791969cffe9474f0ff16a45a9ebfccdb

  # Top-level Zig dependencies
  - kind: remote
    url: ghostty_deps:libxev-34fa50878aec6e5fa8f532867001ab3c36fae23e.tar.gz
    ref: 6003ea6b96e4a518a128f932327d79a11bd30996b13b73baeb29916379487dd7
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:vaxis-7dbb9fd3122e4ffad262dd7c151d80d863b68558.tar.gz
    ref: 2e72332bc89c5b541ec6e6bd48769e1f3fb757c4006f3d1af940b54f9b088ef6
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:z2d-0.10.0-j5P_Hu-6FgBsZNgwphIqh17jDnj8_yPtD8yzjO6PpHRQ.tar.gz
    ref: 69f21da2efd5ee0937fe55c4d09e48afc4fb2f91a01ef167c8c275ae046797f7
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:zig_objc-f356ed02833f0f1b8e84d50bed9e807bf7cdc0ae.tar.gz
    ref: dd84af737625356fcd722cb30909f3b2e8d702667cf579714aa7eabc0ac08ecc
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:zig_js-04db83c617da1956ac5adc1cb9ba1e434c1cb6fd.tar.gz
    ref: 4c2018e56015d39504b8090386ad9ce9393f38380085d9c32373bf7e56fc73a3
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:uucode-0.2.0-ZZjBPqZVVABQepOqZHR7vV_NcaN-wats0IB6o-Exj6m9.tar.gz
    ref: d0abee0f4f8bd6eae3c051777e16e7c42d8964aaaa015591c4e565703f465f95
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:zig_wayland-1b5c038ec10da20ed3a15b0b2a6db1c21383e8ea.tar.gz
    ref: 4f146b735ed0d527f520e3bf71d3e93f72c3d0fa583ae8edd3a4851f7079124e
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:zf-3c52637b7e937c5ae61fd679717da3e276765b23.tar.gz
    ref: 3b015d928af04e9e26272bc15eb4dbb4d9a9d469eb6d290a0ddae673b77c4568
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:gobject-2025-11-08-23-1.tar.zst
    ref: d9bd4306f0081d8e4b848b6adfeabd2fab49822ee2b679eb4801dcedf5d60c48
    directory: zig-deps

  # Wayland dependencies
  - kind: remote
    url: ghostty_deps:wayland-9cb3d7aa9dc995ffafdbdef7ab86a949d0fb0e7d.tar.gz
    ref: ea4191d68e437677e51f3aacde27829810144e931d397a327dc6035e2c39c50d
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:wayland-protocols-258d8f88f2c8c25a830c6316f87d23ce1a0f12d9.tar.gz
    ref: 5cedcadde81b75e60f23e5e83b5dd2b8eb4efb9f8f79bd7a347d148aeb0530f8
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:plasma_wayland_protocols-12207e0851c12acdeee0991e893e0132fc87bb763969a585dc16ecca33e88334c566.tar.gz
    ref: 5c58ba214acd8e6bca3426dc08b022c46a8dd997b29a1b3e28badf71c20df441
    directory: zig-deps

  # Fonts
  - kind: remote
    url: ghostty_deps:JetBrainsMono-2.304.tar.gz
    ref: c57a691e8b82ad098b5963f3959032e4038f391087af7715885ba59046105cc4
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:NerdFontsSymbolsOnly-3.4.0.tar.gz
    ref: 1164d1b956d4bde248d7b2f0998c43cc94f5202431a1564a793895b1e73b0d04
    directory: zig-deps

  # Themes
  - kind: remote
    url: ghostty_deps:ghostty-themes-release-20260216-151611-fc73ce3.tgz
    ref: 14200bb86a0c814ab69609d500b280b396b6d2eb835edf0676de4a789c0aa8fd
    directory: zig-deps

  # Nested pkg/ dependencies
  - kind: remote
    url: ghostty_deps:breakpad-b99f444ba5f6b98cac261cbb391d8766b34a5918.tar.gz
    ref: 6cca98943d1a990766cef61077c09aff5938063fe17a1efe1228e5412b6d6ad9
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:DearBindings_v0.17_ImGui_v1.92.5-docking.tar.gz
    ref: 8bfec500e00926f679853ee23d67cc392d3c3181733ca4704738651d3f70baa3
    directory: zig-deps

  - kind: remote
    url: github_files:ocornut/imgui/archive/refs/tags/v1.92.5-docking.tar.gz
    ref: c816c20e8c75f3e15ae867350e79925502d1a6a85938bb1a73b8927e5f31f9cb
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:fontconfig-2.14.2.tar.gz
    ref: 3ba2dd92158718acec5caaf1a716043b5aa055c27b081d914af3ccb40dce8a55
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:freetype-1220b81f6ecfb3fd222f76cf9106fecfa6554ab07ec7fdc4124b9bb063ae2adf969d.tar.gz
    ref: 427201f5d5151670d05c1f5b45bef5dda1f2e7dd971ef54f0feaaa7ffd2ab90c
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:glslang-12201278a1a05c0ce0b6eb6026c65cd3e9247aa041b1c260324bf29cee559dd23ba1.tar.gz
    ref: 14a2edbb509cb3e51a9a53e3f5e435dbf5971604b4b833e63e6076e8c0a997b5
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:gtk4-layer-shell-1.1.0.tar.gz
    ref: 98284281260a5eef5b4f63a55f16c4bf6a788a1020a6db037ecb0f71fa336988
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:harfbuzz-11.0.0.tar.xz
    ref: f16351bafe214725fe2c1d5b59f0d93e49905a4b247899fb90d70cff953a2b9b
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:highway-66486a10623fa0d72fe91260f96c892e41aceb06.tar.gz
    ref: 87d4f8893ef4e08f224973608ffebf94268a81380ba79c12e8841968c80aa212
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:gettext-0.24.tar.gz
    ref: c918503d593d70daf4844d175a13d816afacb667c06fba1ec9dcd5002c1518b7
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:libpng-1220aa013f0c83da3fb64ea6d327f9173fa008d10e28bc9349eac3463457723b1c66.tar.gz
    ref: fecc95b46cf05e8e3fc8a414750e0ba5aad00d89e9fdf175e94ff041caf1a03a
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:libxml2-2.11.5.tar.gz
    ref: 6c28059e2e3eeb42b5b4b16489e3916a6346c1095a74fee3bc65cdc5d89a6215
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:oniguruma-1220c15e72eadd0d9085a8af134904d9a0f5dfcbed5f606ad60edc60ebeccd9706bb.tar.gz
    ref: 001aa1202e78448f4c0bf1a48c76e556876b36f16d92ce3207eccfd61d99f2a0
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:sentry-1220446be831adcca918167647c06c7b825849fa3fba5f22da394667974537a9c77e.tar.gz
    ref: 2ac6497cc8d61a8d31093e47addb8c9b2c45b16b0705bb334a835b6423c318df
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:spirv_cross-1220fb3b5586e8be67bc3feb34cbe749cf42a60d628d2953632c2f8141302748c8da.tar.gz
    ref: b52b6fcfc45e7fa69b1f06a1362c155473444e2cc09995556b156c53ba6657e3
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:utfcpp-1220d4d18426ca72fc2b7e56ce47273149815501d0d2395c2a98c726b31ba931e641.tar.gz
    ref: ffc668a310e77607d393f3c18b32715f223da1eac4c4d6e0579a11df8e6b59cf
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:wuffs-122037b39d577ec2db3fd7b2130e7b69ef6cc1807d68607a7c232c958315d381b5cd.tar.gz
    ref: 9e4cd20abe96e6c4c6ede9c3057108860126e7be2e2c3e35515476c250be1c13
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:pixels-12207ff340169c7d40c570b4b6a97db614fe47e0d83b5801a932dcd44917424c8806.tar.gz
    ref: 55e83b16d091082502bf149bf457f31f42092c5982650e3ffbae7b48871bf11a
    directory: zig-deps

  - kind: remote
    url: ghostty_deps:zlib-1220fed0c74e1019b3ee29edae2051788b080cd96e90d56836eea857b0b966742efb.tar.gz
    ref: 17e88863f3600672ab49182f217281b6fc4d3c762bde361935e436a95214d05c
    directory: zig-deps

  # Transitive dependencies from vaxis
  - kind: remote
    url: github_files:ivanstepanovftw/zigimg/archive/d7b7ab0ba0899643831ef042bd73289510b39906.tar.gz
    ref: 2c1ed76ba2b35514544b0c27c9633ecba7c31be9080e37e7a010c93b5a1bc553
    directory: zig-deps

  - kind: remote
    url: github_files:jacobsandlund/uucode/archive/5f05f8f83a75caea201f12cc8ea32a2d82ea9732.tar.gz
    ref: 40b90ae087e26546a57961c40ae0cae1926d94140502bafd0f551db9de66e62a
    directory: zig-deps-git

config:
  build-commands:
    # Stage 1: Set up Zig cache
    - |
      export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
      export ZIG_LIB_DIR="%{libdir}/zig"
      mkdir -p "$ZIG_GLOBAL_CACHE_DIR/p"

    # Stage 2: Populate cache from HTTP deps via zig fetch
    - |
      export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
      export ZIG_LIB_DIR="%{libdir}/zig"
      for dep in zig-deps/*; do
        echo "Fetching: $dep"
        zig fetch --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" "$dep" || {
          echo "WARNING: zig fetch failed for $dep" >&2
        }
      done

    # Stage 3: Place git deps that can't be resolved via zig fetch
    - |
      export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"

      place_git_dep() {
        local tarball="$1"
        local zig_hash="$2"
        local dest="$ZIG_GLOBAL_CACHE_DIR/p/$zig_hash"
        mkdir -p "$dest"
        tar xf "$tarball" --strip-components=1 -C "$dest"
        echo "Placed git dep at $dest"
      }

      # uucode: transitive dep of vaxis via git+https://
      place_git_dep \
        "zig-deps-git/5f05f8f83a75caea201f12cc8ea32a2d82ea9732.tar.gz" \
        "uucode-0.1.0-ZZjBPj96QADXyt5sqwBJUnhaDYs_qBeeKijZvlRa0eqM"

  install-commands:
    - |
      export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
      export ZIG_LIB_DIR="%{libdir}/zig"
      # zig 0.15 caps its bundled glibc stubs at 2.42; fdsdk 26.08 ships
      # glibc 2.44, so libs reference 2.43+ symbols the stubs lack. Point
      # zig at the real system libc instead of its stubs.
      cat > /tmp/system-libc.conf <<LIBC
      include_dir=/usr/include
      sys_include_dir=$(ls -d /usr/include/*-linux-gnu 2>/dev/null | head -n1 || echo /usr/include)
      crt_dir=%{libdir}
      msvc_lib_dir=
      kernel32_lib_dir=
      gcc_dir=
      LIBC
      sed -i 's/^      //' /tmp/system-libc.conf
      DESTDIR="%{install-root}" \
      zig build \
        --libc /tmp/system-libc.conf \
        --prefix /usr \
        --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" \
        -Doptimize=ReleaseFast \
        -Dcpu=baseline \
        -Dpie=true \
        -Demit-docs=false \
        -Dversion-string=1.3.1
