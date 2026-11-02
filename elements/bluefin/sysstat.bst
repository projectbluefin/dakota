kind: autotools

sources:
- kind: git_repo
  url: github:sysstat/sysstat.git
  track: v*
  ref: v12.8.0-0-gffabe8175aa9a7aa056380c66ed3648e50c1967d

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/systemd.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  # Build in-tree: sysstat's Makefile.in compiles directly from the source root.
  build-dir: .
  conf-local: >-
    --disable-file-attr
    --disable-stripping
    --disable-documentation
    --disable-nls
    --disable-pcp
    --disable-sensors
    --enable-install-cron
    --enable-copy-only
    --with-systemdsystemunitdir=%{indep-libdir}/systemd/system
    --with-systemdsleepdir=%{indep-libdir}/systemd/system-sleep
    sa_lib_dir=%{indep-libdir}/sa
    sa_dir=%{localstatedir}/log/sa

config:
  install-commands:
    (>):
    # /var is wiped in bluefin-stack.bst; recreate /var/log/sa at boot via tmpfiles.d.
    - rm -rf "%{install-root}%{localstatedir}"
    - |
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/tmpfiles.d/sysstat.conf"
      cat > "%{install-root}%{indep-libdir}/tmpfiles.d/sysstat.conf" <<'EOF'
      d /var/log/sa 0755 root root -
      EOF
    # Collection is opt-in: sar/iostat/mpstat/pidstat work on demand without it.
    # Dakota's presets have no catch-all `disable *`, so unlisted units with an
    # [Install] section would be enabled; disable them explicitly. The sleep
    # hook writes sa records on every suspend regardless, so drop it too.
    # Enable with: systemctl enable --now sysstat.service
    - |
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-sysstat.preset"
      cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-sysstat.preset" <<'EOF'
      disable sysstat.service
      disable sysstat-collect.timer
      disable sysstat-summary.timer
      disable sysstat-rotate.timer
      EOF
    - rm -f "%{install-root}%{indep-libdir}/systemd/system-sleep/sysstat.sleep"
    - install -Dm644 COPYING "%{install-root}%{datadir}/licenses/sysstat/COPYING"
