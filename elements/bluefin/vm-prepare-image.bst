# freedesktop-sdk's vm/prepare-image.bst, replaced so the script can run inside
# BuildBarn's chroot sandbox.
#
# bb_runner chroots into the action's input root, which has no procfs. The
# systemd tools this script drives (systemd-firstboot first) then fail with a
# bare `exit 1` — the only hint is a warning that the kernel command line could
# not be read — and the whole element dies with:
#
#   Running systemd-firstboot
#   Failed to parse systemd.firstboot= kernel command line argument, ignoring
#   Command 'prepare-image.sh … --noroot --noboot >/dev/null' failed with exitcode 1
#
# The copy in files/vm-prepare-image/ mounts a private procfs when none is
# present and unmounts it on exit. That procfs shows this action's own
# processes, so the build stays hermetic; binding the host's /proc would not.
# util-linux is pulled in for mount(8), which upstream's runtime set omits.
#
# Drop this override once bb_runner can mount /proc itself
# (bb-remote-execution#115) — at that point upstream's element works unchanged.
kind: manual

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

runtime-depends:
- freedesktop-sdk.bst:components/findutils.bst
- freedesktop-sdk.bst:components/kmod.bst
- freedesktop-sdk.bst:components/sed.bst
- freedesktop-sdk.bst:components/systemd.bst
- freedesktop-sdk.bst:components/tzdata.bst
- freedesktop-sdk.bst:components/util-linux.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    install -Dm 755 -t "%{install-root}%{bindir}" prepare-image.sh

sources:
- kind: local
  path: files/vm-prepare-image/prepare-image.sh
