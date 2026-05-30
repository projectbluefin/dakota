kind: stack

depends:
  - gnome-build-meta.bst:gnomeos-deps/deps.bst

  - bluefin/gnome-shell-extensions.bst

  - bluefin/brew.bst
  - bluefin/brew-tarball.bst

  - bluefin/tailscale.bst
  - bluefin/uupd.bst


  - bluefin/ghostty.bst

  - bluefin/glow.bst
  - bluefin/gum.bst
  - bluefin/fzf.bst
  - bluefin/tealdeer.bst

  - bluefin/common.bst
  - bluefin/just-overrides.bst
  - bluefin/motd.bst
  - bluefin/firstboot-date.bst
  - bluefin/firstboot-services.bst
  - bluefin/wallpaper-month.bst
  - bluefin/bootc-install-config.bst
  - bluefin/composefs-loop-udisks-ignore.bst
  - bluefin/gnome-epub-thumbnailer.bst
  - bluefin/papers-thumbnailer.bst
  - bluefin/wallpapers.bst

  - bluefin/jetbrains-mono.bst
  - bluefin/jetbrains-mono-nerd-font.bst

  - bluefin/uutils-coreutils.bst
  - bluefin/sudo-rs.bst
  - bluefin/efibootmgr.bst
  - bluefin/xdg-terminal-exec.bst
  - bluefin/nautilus-python.bst
  - bluefin/gnome-ponytail-daemon.bst
  - bluefin/network.bst
  - bluefin/countme.bst

  # Include things missing from the gnomeos base image
  - gnome-build-meta.bst:core-deps/fwupd.bst

  - freedesktop-sdk.bst:components/buildstream2.bst
  - freedesktop-sdk.bst:components/containers-common.bst
  - freedesktop-sdk.bst:components/debuginfod.bst
  - freedesktop-sdk.bst:components/git-lfs.bst
  - freedesktop-sdk.bst:components/git.bst
  - freedesktop-sdk.bst:components/podman.bst
  - freedesktop-sdk.bst:components/skopeo.bst

  - freedesktop-sdk.bst:components/bpf.bst
  - freedesktop-sdk.bst:components/vmlinuxh.bst
  - gnome-build-meta.bst:gnomeos-deps/bpftop.bst
  - gnome-build-meta.bst:core/sysprof-app.bst

  - bluefin/distrobox.bst
  - gnome-build-meta.bst:gnomeos-deps/just.bst
  - gnome-build-meta.bst:gnomeos-deps/wl-clipboard.bst
