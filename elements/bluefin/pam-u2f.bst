kind: autotools
description: |
  U2F/FIDO2 PAM module and pamu2fcfg enrollment tool. Authentication remains
  opt-in: this package installs no PAM service configuration.

sources:
- kind: tar
  # Release signature verified against Yubico's published signing key:
  # F475928225229F58460640EAD91777C175533EE5 (Giovanni Simoni).
  url: yubico:pam-u2f/Releases/pam_u2f-1.4.0.tar.gz
  ref: a59927cea38ea8d91a6836a04e20fc629edde4204b16082f703f6db378e9c634

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/linux-pam-base.bst
- freedesktop-sdk.bst:components/libfido2.bst
- freedesktop-sdk.bst:components/openssl.bst
- freedesktop-sdk.bst:components/systemd-libs.bst

variables:
  conf-local: >-
    --with-pam-dir=%{libdir}/security
    --disable-man

config:
  install-commands:
    (>):
    # The release includes generated manuals; no AsciiDoc toolchain needed.
    - install -Dm644 man/pamu2fcfg.1 "%{install-root}%{mandir}/man1/pamu2fcfg.1"
    - install -Dm644 man/pam_u2f.8 "%{install-root}%{mandir}/man8/pam_u2f.8"
    - install -Dm644 COPYING "%{install-root}%{datadir}/licenses/pam-u2f/COPYING"
