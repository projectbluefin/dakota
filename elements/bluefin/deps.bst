kind: stack

depends:
  - gnome-build-meta.bst:gnomeos-deps/deps.bst

  - bluefin/gnome-shell-extensions.bst

  - bluefin/brew.bst
  - bluefin/brew-tarball/brew-tarball.bst

  - bluefin/tailscale/tailscale.bst

  - bluefin/1password-cli/1password-cli.bst
  - bluefin/1password/1password.bst

  - bluefin/ghostty.bst

  - bluefin/glow/glow.bst
  - bluefin/gum/gum.bst
  - bluefin/fzf/fzf.bst

  - bluefin/common.bst
  - bluefin/wallpapers.bst

  - bluefin/jetbrains-mono.bst
  - bluefin/jetbrains-mono-nerd-font.bst

  - bluefin/uutils-coreutils.bst
  - bluefin/sudo-rs.bst

  # Include things missing from the gnomeos base image
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

  - gnome-build-meta.bst:gnomeos-deps/distrobox.bst
  - gnome-build-meta.bst:gnomeos-deps/just.bst
  - gnome-build-meta.bst:gnomeos-deps/wl-clipboard.bst
