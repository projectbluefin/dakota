kind: manual

sources:
- kind: tar
  url: github_files:vicinaehq/vicinae/releases/download/v0.28.1/vicinae-linux-x86_64-v0.28.1.tar.gz
  ref: 4bc9ad954742a48a771e0b5d2dbcff85091c6215aa655405ab576566047b5488

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 bin/vicinae "%{install-root}%{bindir}/vicinae"

    for f in libexec/vicinae/*; do
      install -Dm755 "$f" "%{install-root}%{prefix}/libexec/vicinae/$(basename "$f")"
    done

    install -Dm644 share/applications/vicinae.desktop "%{install-root}%{datadir}/applications/vicinae.desktop"
    install -Dm644 share/applications/vicinae-url-handler.desktop "%{install-root}%{datadir}/applications/vicinae-url-handler.desktop"

    install -Dm644 share/icons/hicolor/512x512/apps/vicinae.png "%{install-root}%{datadir}/icons/hicolor/512x512/apps/vicinae.png"

    mkdir -p "%{install-root}%{datadir}/vicinae"
    cp -r share/vicinae/* "%{install-root}%{datadir}/vicinae/"

    install -Dm644 lib/systemd/user/vicinae.service "%{install-root}%{indep-libdir}/systemd/user/vicinae.service"

    mkdir -p "%{install-root}%{indep-libdir}/systemd/user/graphical-session.target.wants"
    ln -sfn ../vicinae.service "%{install-root}%{indep-libdir}/systemd/user/graphical-session.target.wants/vicinae.service"

    install -Dm644 lib/modules-load.d/vicinae.conf "%{install-root}%{indep-libdir}/modules-load.d/vicinae.conf"
  - |
    %{install-extra}
