kind: manual

sources:
- kind: local
  path: files/motd

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

public:
  bst:
    overlap-whitelist:
    - /usr/bin/ublue-motd
    - /usr/share/ublue-os/motd/template.md
    - /usr/share/ublue-os/motd/tips/10-tips.md
    - /etc/profile.d/bluefin-shell-defaults.sh

config:
  install-commands:
  - install -Dm755 ublue-motd "%{install-root}%{bindir}/ublue-motd"
  - install -Dm644 template.md "%{install-root}/usr/share/ublue-os/motd/template.md"
  - install -Dm644 tips/10-tips.md "%{install-root}/usr/share/ublue-os/motd/tips/10-tips.md"
  - |
    install -Dm644 /dev/stdin "%{install-root}%{sysconfdir}/profile.d/bluefin-shell-defaults.sh" <<'EOF'
    : "${BLUEFIN_SHELL_ENABLE_MOTD:=1}"
    export BLUEFIN_SHELL_ENABLE_MOTD
    EOF
  - "%{install-extra}"
