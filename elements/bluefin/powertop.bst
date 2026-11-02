kind: meson
description: |
  PowerTOP, a tool to diagnose power consumption and power management issues.

  Only the binary, man page, bash completion and translations are installed.
  Upstream's powertop.service (--auto-tune at boot) is not installed by the
  meson build and is intentionally not shipped: auto-tuning conflicts with
  power-profiles-daemon and must stay a user decision.

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/gettext.bst
- freedesktop-sdk.bst:components/sed.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:bootstrap/ncurses.bst
- freedesktop-sdk.bst:components/libnl.bst
- freedesktop-sdk.bst:components/pciutils.bst
- bluefin/libtracefs.bst

sources:
- kind: tar
  url: github_files:fenrus75/powertop/archive/refs/tags/v2.16.1.tar.gz
  ref: 73d5e96d992ed7f040e17c6c9130deebcf42c38990711840981c7afac6f7832f
