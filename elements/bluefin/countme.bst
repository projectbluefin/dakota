kind: manual

sources:
- kind: local
  path: files/countme

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm644 bluefin-countme.{service,timer} -t "%{install-root}/usr/lib/systemd/system/"
  - mkdir -p "%{install-root}/usr/lib/systemd/system/timers.target.wants/"
  - ln -sf ../bluefin-countme.timer "%{install-root}/usr/lib/systemd/system/timers.target.wants/bluefin-countme.timer"
