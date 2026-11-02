# Disable kexec at boot. Nothing in Dakota boots through kexec (bootc
# upgrades and soft-reboot do not use it), and Epic's Easy Anti-Cheat
# requires it off: a kexec'd kernel would skip the measured boot chain.
# The sysctl is one-way, so it cannot be turned back on until reboot.
kind: manual

build-depends:
- core/sandbox-tools.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    install -d "%{install-root}/usr/lib/sysctl.d"
    cat > "%{install-root}/usr/lib/sysctl.d/60-kexec-disable.conf" <<'EOF'
    kernel.kexec_load_disabled = 1
    EOF
