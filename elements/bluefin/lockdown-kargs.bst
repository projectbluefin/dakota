# Kernel lockdown in integrity mode for signed images. Epic's Easy
# Anti-Cheat requires lockdown to be set explicitly on the kernel command
# line. Integrity mode refuses unsigned modules, so this ships only with
# `-o secure_boot_signing true`, where every module is signed (see
# bluefin/secure-boot.bst). It also disables hibernation, /dev/mem writes,
# and unsigned kexec.
#
# bootc applies these from /usr/lib/bootc/kargs.d/ on install, switch, and
# upgrade.
kind: manual

build-depends:
- core/sandbox-tools.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    install -d "%{install-root}/usr/lib/bootc/kargs.d"
    cat > "%{install-root}/usr/lib/bootc/kargs.d/20-lockdown.toml" <<'EOF'
    kargs = ["lockdown=integrity"]
    EOF
