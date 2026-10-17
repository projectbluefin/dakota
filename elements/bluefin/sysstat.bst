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
    - install -Dm644 COPYING "%{install-root}%{datadir}/licenses/sysstat/COPYING"
