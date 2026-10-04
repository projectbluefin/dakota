# Kernel-only OCI produced by projectbluefin/dakota-kernel-ubuntu.
# Update the digest only after verifying the producer's successful signed run.
kind: import
description: Ubuntu generic kernel, modules and matching development headers

(?):
- arch != "x86_64":
    (!): The published Ubuntu kernel currently supports x86_64 only.

sources:
- kind: docker
  url: ghcr:projectbluefin/dakota-kernel-ubuntu
  architecture: amd64
  os: linux
  track: latest
  ref: 3369b0566ae1431fe1127a82c72e4b5af81277219ebd2b31ae566e52a597f3a1

public:
  bst:
    split-rules:
      devel:
        (>):
        - /usr/src
        - /usr/src/**
        - /usr/lib/modules/*/build
        - /usr/lib/modules/*/System.map
        - /usr/lib/modules/*/vmlinux
      runtime:
        (>):
        - /usr/lib/modules/*/vmlinuz
        - /usr/lib/modules/*/config
        - /usr/lib/modules/*/kernel/**
        - /usr/lib/modules/*/modules.*
