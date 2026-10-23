kind: manual

sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: tailscale_pkgs:tailscale_1.104.1_amd64.tgz
      ref: 108d1d96ecf410d305571e173516f27038f870919a9b89c914a167c6d33a4528
  - arch == "aarch64":
      url: tailscale_pkgs:tailscale_1.104.1_arm64.tgz
      ref: f60294374967f3dfd8cf57bbbd474d6cfce32d123e3a8ddeab82a87940daa806

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/sed.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 -t "%{install-root}%{bindir}" tailscale tailscaled
  - |
    sed -e 's|/usr/sbin/tailscaled|/usr/bin/tailscaled|g' \
        -e '/^EnvironmentFile=/d' \
        systemd/tailscaled.service > tailscaled.service.patched
    sed -i '/^\[Service\]/a Environment=FLAGS=' tailscaled.service.patched
    sed -i '/^\[Service\]/a Environment=PORT=41641' tailscaled.service.patched
    install -Dm644 -t "%{install-root}%{indep-libdir}/systemd/system" tailscaled.service.patched
    mv "%{install-root}%{indep-libdir}/systemd/system/tailscaled.service.patched" \
       "%{install-root}%{indep-libdir}/systemd/system/tailscaled.service"
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-tailscale.preset"
    cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-tailscale.preset" <<'PRESET'
    enable tailscaled.service
    PRESET
  - |
    %{install-extra}
