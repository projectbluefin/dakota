kind: manual
description: |
  Prevent WirePlumber from exposing the PC-speaker ALSA card as a desktop
  audio device. Keep the kernel driver loaded for console beeps, but avoid
  selecting the unusable mono fallback sink after suspend/resume.
  Fixes projectbluefin/dakota#1248.

sources:
- kind: local
  path: files/wireplumber

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm644 51-disable-pcsp.conf \
      "%{install-root}%{datadir}/wireplumber/wireplumber.conf.d/51-disable-pcsp.conf"
