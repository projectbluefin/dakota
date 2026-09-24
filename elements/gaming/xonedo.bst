# OGC xonedo — Xbox One / Series X|S wireless-dongle driver.
#
# Bazzite GNOME parity: Bazzite ships xonedo from akmods (*xonedo*.rpm),
# autoloads xone_dongle + xone_gip_gamepad, keeps in-kernel xpad enabled
# (the whole point of the OGC rename vs legacy medusalix xone), and
# installs the dongle firmware. This reproduces that without RPM/DKMS:
# out-of-tree kmod built against the freedesktop-sdk kernel, merged-usr
# install, depmod resolved at OCI assembly.
kind: manual

sources:
- kind: git
  url: github:OpenGamingCollective/xonedo
  track: master
  # Track past dlundqvist/xone v0.4.11 (suspend/resume fix Bazzite
  # picked up in kernel-bazzite 6.17.7-ba15). Bump with:
  #   just bst source track gaming/xonedo.bst
  ref: 9e8a34e5f6a1d2c3b4a5f60718293a4b5c6d7e810

build-depends:
- core/sandbox-tools.bst
- filename: freedesktop-sdk.bst:components/linux.bst
  strict: true
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  build-commands:
  - make -j$(nproc) KDIR=/usr/src/linux
  - |
    version="$(ls -1 /usr/src/linux 2>/dev/null || ls -1 /usr/lib/modules | head -n1)"
    # KDIR layout varies; fall back to modules dir version.
    if [ ! -d "/usr/src/linux" ]; then version="$(ls -1 /usr/lib/modules | head -n1)"; fi
    moddir="%{install-root}/usr/lib/modules/${version}/extra/xonedo"
    mkdir -p "${moddir}"
    find . -name '*.ko' -exec install -Dm644 {} "${moddir}/" \;
  install-commands:
  - |
    install -Dm644 install/50-xonedo.rules "%{install-root}%{indep-libdir}/udev/rules.d/50-xonedo.rules" || \
    install -Dm644 install/50-xone.rules "%{install-root}%{indep-libdir}/udev/rules.d/50-xonedo.rules"
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/modules-load.d/xonedo.conf"
    printf 'xone_dongle\nxone_gip_gamepad\n' > "%{install-root}%{indep-libdir}/modules-load.d/xonedo.conf"
  - |
    %{install-extra}
