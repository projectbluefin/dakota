kind: manual
description: |
  Subordinate UID/GID ranges for systemd-homed users. useradd gives classic
  users a /etc/subuid and /etc/subgid range; homectl does not, so rootless
  podman, distrobox and toolbox fail for homed users.

  Ships /usr/libexec/bluefin-homed-subids, which gives each homed user
  without a range a free 64K block via usermod, and a user@.service drop-in
  that runs it as root before every user manager starts, i.e. before the
  first process of any login session. Blocks come from systemd's container
  UID range (524288..1879048191), which homed passes through its idmapped
  home mount, starting at 600113152 so they stay clear of the ranges
  useradd hands out (up to SUB_UID_MAX, 600100000). Non-homed users are
  never touched.

sources:
- kind: local
  path: files/homed-subids

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 bluefin-homed-subids \
            "%{install-root}/usr/libexec/bluefin-homed-subids"
  - |
    install -Dm644 50-bluefin-subids.conf \
            "%{install-root}%{indep-libdir}/systemd/system/user@.service.d/50-bluefin-subids.conf"
