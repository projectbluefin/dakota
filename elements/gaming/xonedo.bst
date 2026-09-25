# OGC xonedo — Xbox One / Series X|S wireless-dongle driver.
#
# Bazzite GNOME parity: Bazzite ships xonedo from akmods (*xonedo*.rpm),
# autoloads xone_dongle + xone_gip_gamepad, keeps in-kernel xpad enabled
# (the whole point of the OGC rename vs legacy medusalix xone), and
# installs the dongle firmware. This reproduces that without RPM/DKMS:
# out-of-tree kmod built against the OGC kernel's build tree, merged-usr
# install, depmod resolved at OCI assembly.
#
# Notes:
# - KDIR points at the kernel's /usr/lib/modules/<rel>/build symlink,
#   which linux-ogc.bst wires to /usr/src/linux-<rel>. `uname -r` is the
#   host kernel in the sandbox, so KVERSION is resolved from the staged
#   modules dir instead.
# - Device permissions come from Valve's Steam udev rules (already in
#   gaming/steam-native.bst); upstream ships no rules file.
# - install/modprobe.conf blacklists mt76x2u (MediaTek WiFi dongle that
#   claims the Xbox receiver USB ID) — NOT xpad. Preserved verbatim for
#   upstream/Bazzite parity. Scope note: kmod `blacklist` only suppresses
#   alias-based autoload; explicit `modprobe mt76x2u` still works, and kmod
#   offers no per-USB-ID blacklist, so a narrower mechanism would diverge
#   from upstream packaging without fixing the underlying ID collision.
kind: manual

sources:
- kind: git
  url: github:OpenGamingCollective/xonedo
  track: master
  # Verified 2026-09-24: HEAD "chore(README): Update relevant bits".
  # Past dlundqvist/xone v0.4.11 (suspend/resume fix Bazzite picked up
  # in kernel-bazzite 6.17.7-ba15). Bump with:
  #   just bst source track gaming/xonedo.bst
  ref: 982cbcb019ae4d2bee5ae69385223409ee555c88

build-depends:
- core/sandbox-tools.bst
- filename: freedesktop-sdk.bst:components/linux.bst
  strict: true
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  build-commands:
  - |
    kver="$(ls -1 /usr/lib/modules | head -n1)"
    make -j$(nproc) KDIR=/usr/lib/modules/${kver}/build M="$PWD"
  - |
    kver="$(ls -1 /usr/lib/modules | head -n1)"
    moddir="%{install-root}/usr/lib/modules/${kver}/extra/xonedo"
    mkdir -p "${moddir}"
    find . -name '*.ko' -exec install -Dm644 {} "${moddir}/" \;
  install-commands:
  - |
    install -Dm644 install/modprobe.conf "%{install-root}%{indep-libdir}/modprobe.d/xonedo-blacklist.conf"
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/modules-load.d/xonedo.conf"
    printf 'xone_dongle\nxone_gip_gamepad\n' > "%{install-root}%{indep-libdir}/modules-load.d/xonedo.conf"
  - |
    %{install-extra}
