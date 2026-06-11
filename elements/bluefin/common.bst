kind: manual

sources:
- kind: git_repo
  url: github:projectbluefin/common.git
  track: main
  ref: v2026.06-238-ga717784d7f6d60579832fac2490d6da1964d3d2a
- kind: git_module
  url: github:projectbluefin/branding/
  path: bluefin-branding
  ref: f5213ca61615bb79a8315fc4c5378a80ca93922e
- kind: local
  path: files/wallpaper-month

build-depends:
- gnome-build-meta.bst:gnomeos-deps/just.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/sed.bst

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

    cp -r system_files/bluefin/usr/./ "%{install-root}%{prefix}/"
    cp -r system_files/shared/usr/./ "%{install-root}%{prefix}/"
    cp -r system_files/bluefin/etc/./ "%{install-root}%{sysconfdir}/"
    cp -r system_files/shared/etc/./ "%{install-root}%{sysconfdir}/"
    cp -r bluefin-branding/system_files/etc/./ "%{install-root}%{sysconfdir}/"

    # Default Bluefin shell MOTD to disabled, while allowing user overrides.
    install -Dm644 /dev/stdin "%{install-root}%{sysconfdir}/profile.d/bluefin-shell-defaults.sh" <<'EOF'
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
    cp "%{install-root}%{datadir}/pixmaps/fedora-logo-icon.png" "%{install-root}%{datadir}/pixmaps/img-logo-icon.png"
    cp "%{install-root}%{datadir}/pixmaps/fedora-logo-icon.png" "%{install-root}%{datadir}/pixmaps/img-logo-icon-dark.png"
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
  - "%{install-extra}"
