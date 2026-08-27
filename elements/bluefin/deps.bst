# Historical path note: despite the directory name, this is Dakota's package
# manifest. Add or remove image content via `.bst` elements here — never via
# dnf/RPM/Containerfile overlay logic.
kind: stack

depends:
  - gnome-build-meta.bst:gnomeos-deps/deps.bst

  - bluefin/gnome-shell-extensions.bst

  - bluefin/brew.bst
  - bluefin/brew-tarball.bst

  - bluefin/tailscale.bst
  - bluefin/uupd.bst


  - bluefin/ghostty.bst

  - bluefin/fastfetch.bst
  - bluefin/gum.bst
  - bluefin/tealdeer.bst
  - bluefin/ydotool.bst
  - bluefin/umotd.bst
  - bluefin/uwelcome.bst

  - bluefin/common.bst
  - bluefin/user-avatars.bst
  - bluefin/just-overrides.bst
  - bluefin/zswap-config.bst
  - bluefin/swapfile.bst
  - bluefin/firstboot-date.bst
  - bluefin/firstboot-services.bst
  - bluefin/wallpaper-month.bst
  - bluefin/bootc-install-config.bst
  - bluefin/composefs-loop-udisks-ignore.bst
  - bluefin/gnome-epub-thumbnailer.bst
  - bluefin/papers-thumbnailer.bst
  - bluefin/wallpapers.bst

  - bluefin/uutils-coreutils.bst
  - bluefin/sudo-rs.bst
  - bluefin/fprintd-system-auth.bst
  - bluefin/efibootmgr.bst
  - bluefin/xdg-terminal-exec.bst
  - bluefin/nautilus-python.bst
  - bluefin/gnome-ponytail-daemon.bst
  # Restores the VTE typelibs the app-drop strips out (dakota#1022)
  - bluefin/vte.bst
  - bluefin/network.bst
  - bluefin/wireplumber-pcsp.bst
  - bluefin/countme.bst
  - bluefin/alsa-utils.bst
  - bluefin/brlaser.bst
  # - bluefin/lsp-plugins-lv2.bst

  # Include things missing from the gnomeos base image
  - gnome-build-meta.bst:core-deps/fwupd.bst

  # system-monitor shell extension needs GTop-2.0.typelib; only reaches the image
  # transitively via gnome-control-center otherwise (projectbluefin/dakota#1163)
  - gnome-build-meta.bst:core-deps/libgtop.bst

  - freedesktop-sdk.bst:components/buildstream2.bst
  - freedesktop-sdk.bst:components/containers-common.bst
  - freedesktop-sdk.bst:components/debuginfod.bst
  - freedesktop-sdk.bst:components/dmidecode.bst
  - freedesktop-sdk.bst:components/git-lfs.bst
  - freedesktop-sdk.bst:components/git.bst
  - freedesktop-sdk.bst:components/podman.bst
  - freedesktop-sdk.bst:components/skopeo.bst
  - freedesktop-sdk.bst:components/flatpak-builder.bst

  - freedesktop-sdk.bst:components/bpf.bst
  - freedesktop-sdk.bst:components/vmlinuxh.bst
  - gnome-build-meta.bst:gnomeos-deps/bpftop.bst
  - gnome-build-meta.bst:core/sysprof-app.bst

  - bluefin/distrobox.bst
  - gnome-build-meta.bst:gnomeos-deps/just.bst
  - gnome-build-meta.bst:gnomeos-deps/wl-clipboard.bst

  - bluefin/bindmounts.bst
  - bluefin/migrate-var-home-passwd.bst

  - gnome-build-meta.bst:gnomeos-deps/snapd.bst
