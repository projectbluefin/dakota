kind: autotools
description: Control external monitor settings over DDC/CI.

sources:
- kind: git_repo
  url: github:rockowitz/ddcutil.git
  track: v*
  exclude:
  - '*-rc*'
  ref: v3.0.2-0-g5085ae9bb1a8e5bd8db717d80dd80a279a0f05fb

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:bootstrap/acl.bst
- freedesktop-sdk.bst:components/glib.bst
- freedesktop-sdk.bst:components/jansson.bst
- freedesktop-sdk.bst:components/libdbus.bst
- freedesktop-sdk.bst:components/libdrm.bst
- freedesktop-sdk.bst:components/libusb.bst
- freedesktop-sdk.bst:components/systemd-libs.bst
- freedesktop-sdk.bst:components/xorg-lib-x11.bst
- freedesktop-sdk.bst:components/xorg-lib-xext.bst
- freedesktop-sdk.bst:components/xorg-lib-xrandr.bst
- freedesktop-sdk.bst:components/zlib.bst

runtime-depends:
- freedesktop-sdk.bst:components/hwdata.bst

# Upstream's `make install` also ships two files that change defaults on every
# machine: %{prefix}/lib/modules-load.d/ddcutil.conf loads i2c-dev at boot, and
# %{prefix}/lib/udev/rules.d/60-ddcutil-i2c.rules tags display-class I2C buses
# with uaccess, so the logged-in seat user can talk DDC/CI without root.
variables:
  # Upstream embeds the build date/time by default; keep builds reproducible.
  # https://www.ddcutil.com/building/
  conf-local: --disable-build-timestamp

config:
  install-commands:
    (>):
    - install -Dm644 COPYING "%{install-root}%{datadir}/licenses/ddcutil/COPYING"
