kind: manual

sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: onepassword_files:linux/tar/stable/x86_64/1password-8.12.10.x64.tar.gz
      ref: 83d6adb7ed43439d1f5ab6ae6c991dc626b0d5ec207db66f435f2662d008aa23
  - arch == "aarch64":
      url: onepassword_files:linux/tar/stable/aarch64/1password-8.12.10.arm64.tar.gz
      ref: 6cd9af5e0feb44cd28b421c577968cfb8ac4b785c557637c420a9942a592aff9

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/sed.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    mkdir -p "%{install-root}/opt/1Password"
    cp -a . "%{install-root}/opt/1Password/"
  - |
    install -dm755 "%{install-root}%{bindir}"
    ln -sf /opt/1Password/1password "%{install-root}%{bindir}/1password"
  - |
    sed 's|/opt/1Password/1password|1password|g' \
        resources/1password.desktop > 1password.desktop.patched
    install -Dm644 1password.desktop.patched \
        "%{install-root}%{datadir}/applications/1password.desktop"
  - |
    for size in 32x32 64x64 256x256 512x512; do
      install -Dm644 "resources/icons/hicolor/${size}/apps/1password.png" \
          "%{install-root}%{datadir}/icons/hicolor/${size}/apps/1password.png"
    done
  - |
    chmod 4755 "%{install-root}/opt/1Password/chrome-sandbox"
  - |
    sed 's/${POLICY_OWNERS}//g' com.1password.1Password.policy.tpl \
        > com.1password.1Password.policy
    install -Dm644 -t "%{install-root}%{datadir}/polkit-1/actions" \
        com.1password.1Password.policy
  - |
    %{install-extra}
