# Dakota Secure Boot certificate (files/boot-keys/modules/linux-module-cert.crt,
# created with `just secure-boot-keygen`), imported to /keys for the kernel
# build. fdsdk-config.sh compiles it into the builtin trusted keyring and
# only enables MODULE_SIG and the lockdown LSM when it is present. The same
# certificate signs the kernel image and EFI binaries and is the MOK users
# enroll.
#
# Replaces gnome-build-meta's element via the freedesktop-sdk junction
# override, whose files/boot-keys/modules is empty outside GNOME's own CI.
kind: import

config:
  target: /keys

sources:
- kind: local
  path: files/boot-keys/modules
