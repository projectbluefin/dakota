kind: manual

sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: github_files:projectbluefin/chairlift/releases/download/v0.12.0/chairlift_0.12.0_linux_amd64.tar.gz
      ref: edd2835b39aac9407ff432a1033a84906f1cd7d636cb152ffe369506b574c9d4
  - arch == "aarch64":
      url: github_files:projectbluefin/chairlift/releases/download/v0.12.0/chairlift_0.12.0_linux_arm64.tar.gz
      ref: 976692a36603536a8409bc250a2d651b5e5e3c958ef72ffc97e1ace9ab660659

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

depends:
- gnome-build-meta.bst:sdk/gtk.bst
- gnome-build-meta.bst:sdk/libadwaita.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 -t "%{install-root}%{bindir}" chairlift chairlift-updex-helper chairlift-ublue-helper
  - |
    install -Dm755 data/chairlift-wrapper.sh "%{install-root}%{bindir}/chairlift-wrapper"
  - |
    install -Dm644 data/io.projectbluefin.chairlift.desktop \
      "%{install-root}%{datadir}/applications/io.projectbluefin.chairlift.desktop"
  - |
    install -Dm644 data/icons/hicolor/scalable/apps/io.projectbluefin.chairlift.svg \
      "%{install-root}%{datadir}/icons/hicolor/scalable/apps/io.projectbluefin.chairlift.svg"
    install -Dm644 data/icons/hicolor/scalable/apps/io.projectbluefin.chairlift-flower.svg \
      "%{install-root}%{datadir}/icons/hicolor/scalable/apps/io.projectbluefin.chairlift-flower.svg"
    install -Dm644 data/icons/hicolor/symbolic/apps/io.projectbluefin.chairlift-symbolic.svg \
      "%{install-root}%{datadir}/icons/hicolor/symbolic/apps/io.projectbluefin.chairlift-symbolic.svg"
  - |
    install -Dm644 data/io.projectbluefin.chairlift.bootc.policy \
      "%{install-root}%{datadir}/polkit-1/actions/io.projectbluefin.chairlift.bootc.policy"
    install -Dm644 data/io.projectbluefin.chairlift.updex.policy \
      "%{install-root}%{datadir}/polkit-1/actions/io.projectbluefin.chairlift.updex.policy"
    install -Dm644 data/io.projectbluefin.chairlift.sysupdate.policy \
      "%{install-root}%{datadir}/polkit-1/actions/io.projectbluefin.chairlift.sysupdate.policy"
    install -Dm644 data/io.projectbluefin.chairlift.ublue.policy \
      "%{install-root}%{datadir}/polkit-1/actions/io.projectbluefin.chairlift.ublue.policy"
  - |
    install -Dm644 config.yml "%{install-root}%{datadir}/chairlift/config.yml"
    install -Dm644 channels.example.yml "%{install-root}%{datadir}/doc/chairlift/channels.example.yml"
  - |
    %{install-extra}
