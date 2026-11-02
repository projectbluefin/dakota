# dakota-secure-boot (behind `ujust enroll-secure-boot-key`) and the boot
# service that keeps the ESP copies of the shim chain in step with the
# image, since bootc upgrades never touch the ESP. Signed images only; see
# bluefin/secure-boot.bst.
kind: manual

build-depends:
- core/sandbox-tools.bst

# The boot layer stages these tools through bluefin/secure-boot-tools-files.bst,
# without these dependencies; bluefin/deps.bst puts them in the base and the
# final OCI elements fail if the base lacks what dakota-secure-boot runs.
depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- bluefin/efibootmgr.bst
- gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/mokutil.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - install -Dm755 dakota-secure-boot "%{install-root}/usr/libexec/dakota-secure-boot"
  - install -Dm644 dakota-secure-boot-update.service "%{install-root}/usr/lib/systemd/system/dakota-secure-boot-update.service"
  - mkdir -p "%{install-root}/usr/lib/systemd/system/multi-user.target.wants"
  - ln -s ../dakota-secure-boot-update.service "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/dakota-secure-boot-update.service"

sources:
- kind: local
  path: files/secure-boot
