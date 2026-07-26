# Native Steam launcher/bootstrap from Valve's Debian package.
#
# This is not an RPM import: we extract Valve's distro-neutral launcher payload
# into the immutable host image so `/usr/bin/steam`, desktop actions, icons,
# MIME handlers, the bootstrap runtime tarball, and Steam Input/VR udev rules
# are present like a Bazzite-style native install. The Steam client itself still
# self-updates into the user's home directory on first launch.
kind: manual

sources:
- kind: remote
  url: steam-static:client/installer/steam.deb
  ref: b44634a6a604ca7c8b23809d0f2a921a0348bb2081c8cb8944116d0799872b70
  filename: steam-1.0.0.85.deb

build-depends:
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/binutils.bst
- freedesktop-sdk.bst:bootstrap/coreutils.bst
- freedesktop-sdk.bst:components/tar.bst
- freedesktop-sdk.bst:components/xz.bst
- freedesktop-sdk.bst:components/python3.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:components/python3.bst
- freedesktop-sdk.bst:components/diffutils.bst
- freedesktop-sdk.bst:components/tar.bst
- freedesktop-sdk.bst:components/xz.bst
- freedesktop-sdk.bst:cross-compilers/standard-libs-i686.bst
- gaming/steam-libs-i686.bst
- freedesktop-sdk.bst:components/vulkan-icd-loader.bst
- freedesktop-sdk.bst:components/compat-vulkan-link.bst
- freedesktop-sdk.bst:components/libpulse.bst
- freedesktop-sdk.bst:components/alsa-plugins.bst
- freedesktop-sdk.bst:components/openal.bst
- freedesktop-sdk.bst:components/libusb.bst
- freedesktop-sdk.bst:components/libgudev.bst
- freedesktop-sdk.bst:components/libevdev.bst
- freedesktop-sdk.bst:components/xorg-lib-x11.bst
- freedesktop-sdk.bst:components/xorg-lib-xcursor.bst
- freedesktop-sdk.bst:components/xorg-lib-xdamage.bst
- freedesktop-sdk.bst:components/xorg-lib-xext.bst
- freedesktop-sdk.bst:components/xorg-lib-xfixes.bst
- freedesktop-sdk.bst:components/xorg-lib-xi.bst
- freedesktop-sdk.bst:components/xorg-lib-xinerama.bst
- freedesktop-sdk.bst:components/xorg-lib-xrandr.bst
- freedesktop-sdk.bst:components/xorg-lib-xrender.bst
- freedesktop-sdk.bst:components/xorg-lib-xscrnsaver.bst
- freedesktop-sdk.bst:components/xorg-lib-xtst.bst
- freedesktop-sdk.bst:components/xorg-lib-xxf86vm.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    mkdir -p deb data "%{install-root}"
    cd deb
    ar x ../steam-1.0.0.85.deb
    cd ..
    tar -xf deb/data.tar.xz -C data

    # Install the immutable host launcher payload.
    cp -a data/usr/. "%{install-root}/usr/"

    # Steam's .deb carries udev rules in /lib for Debian usr-merge. Install
    # them into FDSDK's canonical /usr/lib/udev location.
    if [ -d data/lib/udev/rules.d ]; then
      mkdir -p "%{install-root}/usr/lib/udev/rules.d"
      cp -a data/lib/udev/rules.d/. "%{install-root}/usr/lib/udev/rules.d/"
    fi

    # Drop Debian apt integration; Dakota has no dpkg/apt database. Keep a no-op
    # steamdeps command so Valve's launcher does not emit python-apt/dpkg noise
    # before continuing.
    rm -rf "%{install-root}/etc/apt"
    install -Dm755 /dev/stdin "%{install-root}/usr/lib/steam/bin_steamdeps.py" <<'EOF'
    #!/usr/bin/env sh
    exit 0
    EOF

    # Ensure Valve's steam-runtime/run.sh sees the host 32-bit library path
    # when it builds LD_LIBRARY_PATH from `ldconfig -XNv`. Without this, the
    # bundled scout runtime can load an older libxcb.so.1 before our matching
    # host libxcb-shm.so.0, causing undefined symbols such as
    # xcb_send_request_with_fds.
    install -Dm644 /dev/stdin "%{install-root}/etc/ld.so.conf.d/00-i386-linux-gnu.conf" <<'EOF'
    /usr/lib/i386-linux-gnu/GL/default/lib
    /usr/lib/i386-linux-gnu
    EOF

    # The x86_64 ldconfig used by steam-runtime/run.sh does not report the
    # i386 library directory, so seed LD_LIBRARY_PATH before handing off to
    # Steam's bootstrap. steam.sh captures this as SYSTEM_LD_LIBRARY_PATH and
    # run.sh then places it before the bundled scout runtime libraries.
    python3 - <<'PY'
    from pathlib import Path
    p = Path('%{install-root}/usr/lib/steam/bin_steam.sh')
    text = p.read_text()
    old = 'cd "$LAUNCHSTEAMDIR"\n\nexec "$LAUNCHSTEAMDIR/$STEAMBOOTSTRAP" ${log_opened+-srt-logger-opened} "$@"\n'
    new = '''cd "$LAUNCHSTEAMDIR"

    # Prefer the host 32-bit runtime slice over Steam scout's older libraries.
    # This keeps libraries such as libxcb.so.1 and libxcb-shm.so.0 ABI-compatible.
    export LD_LIBRARY_PATH="/usr/lib/i386-linux-gnu/GL/default/lib:/usr/lib/i386-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    exec "$LAUNCHSTEAMDIR/$STEAMBOOTSTRAP" ${log_opened+-srt-logger-opened} -cef-disable-gpu "$@"
    '''
    if old not in text:
        raise SystemExit('failed to locate Steam bootstrap exec block')
    p.write_text(text.replace(old, new))
    PY

    # The package also installs /usr/lib/steam/steam.desktop -> the shared
    # desktop file; ensure the symlink survived archive extraction.
    ln -sfn ../../share/applications/steam.desktop "%{install-root}/usr/lib/steam/steam.desktop"
