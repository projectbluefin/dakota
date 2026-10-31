# Historical path note: despite the directory name, this is Dakota's package
# manifest. Add or remove image content via `.bst` elements here — never via
# dnf/RPM/Containerfile overlay logic.
kind: stack

depends:
  - gnome-build-meta.bst:gnomeos-deps/deps.bst

  - bluefin/gnome-shell-extensions.bst

  # IBus Rime; users select their own input sources in GNOME.
  - bluefin/ibus-rime.bst

  - bluefin/brew.bst
  - bluefin/brew-tarball.bst

  - bluefin/tailscale.bst
  - bluefin/uupd.bst
  - bluefin/chairlift.bst


  - bluefin/ghostty.bst

  - bluefin/fastfetch.bst
  - bluefin/nerd-fonts-symbols.bst
  - bluefin/gum.bst
  - bluefin/tealdeer.bst
  - bluefin/ydotool.bst
  - bluefin/umotd.bst
  - bluefin/uwelcome.bst

  - bluefin/common.bst
  - bluefin/user-avatars.bst
  - bluefin/just-overrides.bst
  - bluefin/zswap-config.bst
  - bluefin/kexec-disable.bst
  - bluefin/swapfile.bst
  - bluefin/firstboot-date.bst
  - bluefin/firstboot-services.bst
  - bluefin/flatpak-apps.bst
  - bluefin/wallpaper-month.bst
  - bluefin/bootc-install-config.bst
  - bluefin/composefs-loop-udisks-ignore.bst
  - bluefin/udev-groups.bst
  - bluefin/gnome-epub-thumbnailer.bst
  # Papers' thumbnailer and PDF backend. The full package already reaches the
  # image through gnome-build-meta's sushi, and the Papers Flatpak's desktop
  # entry takes precedence in XDG_DATA_DIRS, so users see one Papers app.
  - gnome-build-meta.bst:core/papers.bst
  - bluefin/wallpapers.bst

  - bluefin/uutils-coreutils.bst
  - bluefin/sudo-rs.bst
  - bluefin/sudo-linuxbrew-path.bst
  - bluefin/fprintd-system-auth.bst
  - bluefin/fprintd-fingerprint-auth.bst
  # efibootmgr and mokutil stay in every image: the Secure Boot tools in
  # the boot layer (oci/layers/boot-stack.bst) run them but cannot carry them.
  - bluefin/efibootmgr.bst
  - gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/mokutil.bst
  - bluefin/xdg-terminal-exec.bst
  - bluefin/nautilus-python.bst
  - bluefin/gnome-ponytail-daemon.bst
  # Restores the VTE typelibs the app-drop strips out (dakota#1022)
  - bluefin/vte.bst
  - bluefin/network.bst
  - bluefin/nfs-utils.bst
  - bluefin/networkmanager-polkit.bst
  - bluefin/wireplumber-pcsp.bst
  - bluefin/alsa-utils.bst
  - bluefin/brlaser.bst
  - bluefin/powertop.bst
  # - bluefin/lsp-plugins-lv2.bst

  # Include things missing from the gnomeos base image
  - gnome-build-meta.bst:core-deps/fwupd.bst

  # system-monitor shell extension needs GTop-2.0.typelib; only reaches the image
  # transitively via gnome-control-center otherwise (projectbluefin/dakota#1163)
  - gnome-build-meta.bst:core-deps/libgtop.bst

  - bluefin/virtualization.bst

  - freedesktop-sdk.bst:components/buildstream2.bst
  - freedesktop-sdk.bst:components/containers-common.bst
  - freedesktop-sdk.bst:components/debuginfod.bst
  - freedesktop-sdk.bst:components/dmidecode.bst
  - freedesktop-sdk.bst:components/git-lfs.bst
  - freedesktop-sdk.bst:components/git.bst
  - freedesktop-sdk.bst:components/podman.bst
  - freedesktop-sdk.bst:components/skopeo.bst
  - freedesktop-sdk.bst:components/flatpak-builder.bst

  - freedesktop-sdk.bst:components/bpf-maybe.bst
  - gnome-build-meta.bst:gnomeos-deps/bpftop.bst
  - gnome-build-meta.bst:core/sysprof-app.bst

  - bluefin/nicstat.bst
  - bluefin/tiptop.bst
  - gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/numactl.bst
  - bluefin/sysstat.bst
  - bluefin/trace-cmd.bst

  - bluefin/distrobox.bst
  - bluefin/nspawn.bst
  - gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/just.bst
  - gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/wl-clipboard.bst

  - bluefin/bindmounts.bst
  - bluefin/migrate-var-home-passwd.bst

  - gnome-build-meta.bst:gnomeos-deps/snapd.bst

  # VM guest agents; each starts only on its own hypervisor.
  - bluefin/qemu-guest-agent.bst
  - bluefin/hyperv-daemons.bst

(?):
- arch == "x86_64":
    depends:
      (>):
      - bluefin/intel-media-driver.bst
      # x86_64 only: the aarch64 kernel enables neither vmwgfx nor VMCI, so
      # display auto-resize, the reason to ship it, cannot work there yet.
      - bluefin/open-vm-tools.bst
