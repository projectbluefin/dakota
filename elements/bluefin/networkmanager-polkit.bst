kind: manual
description: |
  Let local wheel users add system NetworkManager connections without a
  password, matching Fedora's -Dpolkit_noauth_group=wheel. Game mode has no
  polkit agent.

sources:
- kind: local
  path: files/polkit

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm644 org.freedesktop.NetworkManager.rules \
      "%{install-root}%{datadir}/polkit-1/rules.d/org.freedesktop.NetworkManager.rules"
