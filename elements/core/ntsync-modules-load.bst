# Load ntsync at boot: the OGC kernel builds CONFIG_NTSYNC=m and
# Wine/Proton probe /dev/ntsync directly; without this nothing loads it.
kind: manual

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/modules-load.d/ntsync.conf"
    cat > "%{install-root}%{indep-libdir}/modules-load.d/ntsync.conf" <<'EOF'
    ntsync
    EOF
