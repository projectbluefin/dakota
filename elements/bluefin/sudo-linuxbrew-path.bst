kind: manual
description: |
  Append the Homebrew prefix to sudo's secure_path so `sudo <brew tool>`
  resolves. The stock /etc/sudoers from C sudo sets secure_path to the
  system directories; sudo-rs reads the same file, and a later drop-in
  replaces the value. Homebrew comes last so it cannot shadow system
  binaries.

build-depends:
- core/sandbox-tools.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:vm/config/sudo.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    install -d "%{install-root}%{sysconfdir}/sudoers.d"
    cat > "%{install-root}%{sysconfdir}/sudoers.d/linuxbrew" <<'EOF'
    Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin"
    EOF
    chmod 0440 "%{install-root}%{sysconfdir}/sudoers.d/linuxbrew"
