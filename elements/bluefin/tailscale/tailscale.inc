build-depends:
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
          -e 's|--port=${PORT}|--port=41641|g' \
          -e 's| ${FLAGS}||g' \
          systemd/tailscaled.service > tailscaled.service.patched
      install -Dm644 -t "%{install-root}%{indep-libdir}/systemd/system" tailscaled.service.patched
      mv "%{install-root}%{indep-libdir}/systemd/system/tailscaled.service.patched" \
         "%{install-root}%{indep-libdir}/systemd/system/tailscaled.service"
    - |
      install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system-preset/80-tailscale.preset" <<'PRESET'
      enable tailscaled.service
      PRESET
    - |
      %{install-extra}
