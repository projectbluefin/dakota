kind: manual

sources: []

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  # The reporter itself comes from projectbluefin/common via bluefin/common.bst,
  # which copies system_files/shared/usr wholesale — the same unit and helper
  # every other image gets. Nothing about counting is Dakota-specific.
  #
  # Only the enablement symlink lives here, because this image enables units
  # through timers.target.wants rather than by running systemctl preset.
  - mkdir -p "%{install-root}/usr/lib/systemd/system/timers.target.wants/"
  - ln -sf ../bluefin-countme.timer "%{install-root}/usr/lib/systemd/system/timers.target.wants/bluefin-countme.timer"

depends:
- bluefin/common.bst
