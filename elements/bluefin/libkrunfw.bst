kind: manual
description: |
  libkrunfw guest kernel payload required by libkrun.

sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: github-releases:libkrun/libkrunfw/releases/download/v5.6.1/libkrunfw-x86_64.tgz
      ref: 16a0e354c7e6a4514251c29cca982e7ab096ff98d51eeb16288d3bcc39e2a2c1
  - arch == "aarch64":
      url: github-releases:libkrun/libkrunfw/releases/download/v5.6.1/libkrunfw-aarch64.tgz
      ref: afe8c9ffc5b4a2290ad4dd6df27605ef97b074151174a1f83e738354cdd66d95

variables:
  strip-binaries: ''

config:
  install-commands:
  - install -Dm755 lib/*/libkrunfw.so.5.6.0 "%{install-root}%{libdir}/libkrunfw.so.5.6.0"
  - ln -s libkrunfw.so.5.6.0 "%{install-root}%{libdir}/libkrunfw.so.5"
  - ln -s libkrunfw.so.5 "%{install-root}%{libdir}/libkrunfw.so"
