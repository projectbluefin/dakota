# systemd-boot and the fwupd capsule loader signed with the Dakota Secure
# Boot key, shipped next to the unsigned binaries with the .signed suffix,
# plus the certificate users enroll as a MOK.
# `bootctl install` (which bootc runs at install time) and fwupd both
# prefer the .signed variant when it exists, so nothing is overwritten and
# no overlap whitelist is needed.
#
# Pulled in by bluefin/secure-boot.bst only with `-o secure_boot_signing
# true`. Same isolation rule as bluefin/signed-modules.bst: never build
# this with push remotes or remote execution.
kind: manual

build-depends:
- core/sandbox-tools.bst
- filename: freedesktop-sdk.bst:components/systemd.bst
  strict: true
- filename: gnome-build-meta.bst:core-deps/fwupd-efi.bst
  strict: true
- freedesktop-sdk.bst:components/openssl.bst
- freedesktop-sdk.bst:components/sbsigntools-maybe.bst

variables:
  strip-binaries: ""
  efi-arch: x64
  (?):
  - arch == "aarch64":
      efi-arch: aa64

config:
  install-commands:
  - |
    install -d "%{install-root}%{indep-libdir}/systemd/boot/efi"
    bash sign.sh efi \
      "%{indep-libdir}/systemd/boot/efi/systemd-boot%{efi-arch}.efi" \
      "%{install-root}%{indep-libdir}/systemd/boot/efi/systemd-boot%{efi-arch}.efi.signed"

  - |
    install -d "%{install-root}%{libexecdir}/fwupd/efi"
    bash sign.sh efi \
      "%{libexecdir}/fwupd/efi/fwupd%{efi-arch}.efi" \
      "%{install-root}%{libexecdir}/fwupd/efi/fwupd%{efi-arch}.efi.signed"

  - |
    install -d "%{install-root}/usr/lib/dakota/secure-boot"
    openssl x509 -in modules/linux-module-cert.crt -outform DER \
      -out "%{install-root}/usr/lib/dakota/secure-boot/dakota-secure-boot.der"

sources:
- kind: local
  path: files/boot-keys
