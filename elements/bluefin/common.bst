kind: manual

sources:
- kind: git_repo
  url: github:projectbluefin/common.git
  track: main
  ref: v2026.08-379-ged945ef0226734a45df5f6a257d672e8886b5567
# Dakota uses Ghostty as primary terminal: enable dual-theme to track GNOME Dark/Light style.
# Drop this patch once common ships dual-theme by default.
- kind: patch
  path: patches/common/0002-ghostty-dual-theme.patch
# Avoid activating the desktop portal from GDM's non-interactive login shell.
# Drop once common ships an interactive-shell guard.
- kind: patch
  path: patches/common/0003-uwelcome-interactive-only.patch
- kind: patch
  path: patches/common/0004-policy-drop-redhat-gpg-entries.patch
# The weekly stats are fetched at build time elsewhere; Dakota builds have no
# network, so drop the two lines rather than print missing-file errors.
- kind: patch
  path: patches/common/0006-fastfetch-drop-weekly-stats.patch
- kind: git_module
  url: github:projectbluefin/branding/
  path: bluefin-branding
  ref: f5213ca61615bb79a8315fc4c5378a80ca93922e
- kind: local
  path: files/wallpaper-month
- kind: remote
  url: github-raw:projectbluefin/artwork/de74de65647f9109594345fd30966136d70fa458/assets/vector/logos/bluefin/bluefin-logo-light.svg
  ref: d336d743082bded58c561c2c53baf1896dae87d7346224d9d06512e6c247cf74
  filename: bluefin-logo-light.svg
- kind: remote
  url: github-raw:projectbluefin/artwork/de74de65647f9109594345fd30966136d70fa458/assets/vector/logos/bluefin/bluefin-logo-dark.svg
  ref: 4ae1d486e6e73743fad1e1ef625615c4a28e72bbcc0a966ba3c5294303e4e380
  filename: bluefin-logo-dark.svg

build-depends:
- core/sandbox-tools.bst
- gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/just.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/sed.bst
# common's /etc/containers/policy.json replaces the permissive stock policy
# from containers-common. A compose keeps whichever element stages last, so
# depend on containers-common to stage it first and let common's policy win.
- freedesktop-sdk.bst:components/containers-common.bst

public:
  bst:
    overlap-whitelist:
    - /etc/environment
    - /etc/containers/policy.json
    - /usr/share/pixmaps/gnome-boot-logo.png

variables:
  strip-binaries: ""

config:
  install-commands:
    #   - install -Dm644 -t "%{install-root}%{sysconfdir}/" etc/*
    #   - install -Dm644 -t "%{install-root}%{sysconfdir}/" etc/*
  - |
    sed -i "s#file:///usr/share/backgrounds/bluefin/12-bluefin.xml#file:///var/lib/ublue-os/current-bluefin.xml#g" "system_files/bluefin/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override"

    # The /var/home/linuxbrew spelling breaks Homebrew's bottle-prefix
    # detection on Dakota's real /home; common respelled everything to
    # /home/linuxbrew in projectbluefin/common#997. Guard against the bad
    # spelling regressing upstream (.agents/skills/dakota-workstation/references/host-homebrew.md).
    # The sandbox has bash, coreutils and sed but no grep or find
    # (core/sandbox-tools.bst), so walk the tree with globstar and print
    # matching files with sed's F command.
    linuxbrew_refs="$(bash -O globstar -O dotglob -O nullglob -c '
      for f in system_files/shared/** system_files/bluefin/**; do
        if [ -f "$f" ] && [ ! -L "$f" ]; then
          sed -n "\#/var/home/linuxbrew#{F;q}" "$f"
        fi
      done')"
    if [ -n "$linuxbrew_refs" ]; then
      printf '%s\n' "$linuxbrew_refs" >&2
      echo "ERROR: /var/home/linuxbrew references above break brew bottle-prefix detection — fix them in projectbluefin/common" >&2
      exit 1
    fi

    cp -r system_files/bluefin/usr/./ "%{install-root}%{prefix}/"
    cp -r system_files/shared/usr/./ "%{install-root}%{prefix}/"
    cp -r system_files/bluefin/etc/./ "%{install-root}%{sysconfdir}/"
    cp -r system_files/shared/etc/./ "%{install-root}%{sysconfdir}/"
    cp -r bluefin-branding/system_files/etc/./ "%{install-root}%{sysconfdir}/"

    # Default Bluefin shell MOTD to disabled, while allowing user overrides.
    install -Dm644 /dev/null "%{install-root}%{sysconfdir}/profile.d/bluefin-shell-defaults.sh"
    cat > "%{install-root}%{sysconfdir}/profile.d/bluefin-shell-defaults.sh" <<'EOF'
    : "${BLUEFIN_SHELL_ENABLE_MOTD:=0}"
    export BLUEFIN_SHELL_ENABLE_MOTD
    EOF

    # Generate ujust completions to match the upstream common image.
    install -d \
      "%{install-root}%{datadir}/bash-completion/completions" \
      "%{install-root}%{datadir}/zsh/site-functions" \
      "%{install-root}%{datadir}/fish/vendor_completions.d"
    just --completions bash | sed -E 's/([\(_" ])just/\1ujust/g' > "%{install-root}%{datadir}/bash-completion/completions/ujust"
    just --completions zsh | sed -E 's/([\(_" ])just/\1ujust/g' > "%{install-root}%{datadir}/zsh/site-functions/_ujust"
    just --completions fish | sed -E 's/([\(_" ])just/\1ujust/g' > "%{install-root}%{datadir}/fish/vendor_completions.d/ujust.fish"

    # Map Bluefin icons to GNOME OS expected names
    # About dialog (gnome-control-center reads LOGO=img-logo-icon from os-release,
    # then looks for img-logo-icon-text-dark, img-logo-icon-text, img-logo-icon-dark, img-logo-icon)
    install -Dm644 bluefin-logo-light.svg "%{install-root}%{datadir}/pixmaps/img-logo-icon-text.svg"
    install -Dm644 bluefin-logo-dark.svg "%{install-root}%{datadir}/pixmaps/img-logo-icon-text-dark.svg"
    install -Dm644 bluefin-logo-light.svg "%{install-root}%{datadir}/pixmaps/img-logo-icon.svg"
    install -Dm644 bluefin-logo-dark.svg "%{install-root}%{datadir}/pixmaps/img-logo-icon-dark.svg"
    # Override GNOME OS boot logo with Bluefin branding
    cp "%{install-root}%{datadir}/pixmaps/fedora-gdm-logo.png" "%{install-root}%{datadir}/pixmaps/gnome-boot-logo.png"
    install -Dm755 bluefin-wallpaper-month-sync "%{install-root}%{prefix}/libexec/bluefin-wallpaper-month-sync"
    install -Dm644 bluefin-wallpaper-month.service "%{install-root}%{prefix}/lib/systemd/system/bluefin-wallpaper-month.service"
    mkdir -p "%{install-root}%{prefix}/lib/systemd/system/multi-user.target.wants"
    ln -sfn ../bluefin-wallpaper-month.service "%{install-root}%{prefix}/lib/systemd/system/multi-user.target.wants/bluefin-wallpaper-month.service"

    # Create dconf profile so the distro system database is read
    mkdir -p "%{install-root}%{sysconfdir}/dconf/profile"
    printf 'user-db:user\nsystem-db:distro\n' > "%{install-root}%{sysconfdir}/dconf/profile/user"

    # Dakota is a fresh BuildStream image — users never migrate from legacy-rechunk.
    # Remove the rechunker-group-fix migration aid that common ships for Bluefin/LTS.
    rm -f "%{install-root}%{prefix}/bin/rechunker-group-fix"
    rm -f "%{install-root}%{prefix}/lib/systemd/system/rechunker-group-fix.service"
    rm -f "%{install-root}%{prefix}/lib/systemd/system-preset/00-rechunker-group-fix.preset"

    # Dakota uses its own ublue-motd (from motd.bst) with a double-display guard.
    # Remove common's umotd.sh hook to prevent dual MOTD on every login.
    rm -f "%{install-root}%{sysconfdir}/profile.d/umotd.sh"

    # System Update, Community and Documentation launchers duplicate Control Center,
    # which already provides updates, the Community discussions link and the Bluefin
    # PDF docs on Dakota. Drop the three icons common ships for Bluefin/bluefin-lts.
    # The `ujust update` command itself is untouched; only the duplicate icons go.
    rm -f "%{install-root}%{prefix}/usr/share/applications/system-update.desktop"
    rm -f "%{install-root}%{prefix}/usr/share/applications/discourse.desktop"
    rm -f "%{install-root}%{prefix}/usr/share/applications/documentation.desktop"

    # Add BudsLink to default system flatpaks
    echo 'flatpak "io.github.maniacx.BudsLink"' >> "%{install-root}%{datadir}/ublue-os/homebrew/system-flatpaks.Brewfile"
  - "%{install-extra}"
