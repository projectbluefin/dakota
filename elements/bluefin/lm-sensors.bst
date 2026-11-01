kind: make

sources:
- kind: git_repo
  url: github:lm-sensors/lm-sensors.git
  track: V*
  ref: V3-6-2-0-g5c3ba50f806dea27c3b1e368966191c735459111

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
- freedesktop-sdk.bst:components/bison.bst
- freedesktop-sdk.bst:components/flex.bst
- freedesktop-sdk.bst:components/perl.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/perl.bst

variables:
  make-args: >-
    PREFIX=%{prefix}
    SBINDIR=%{bindir}
    BINDIR=%{bindir}
    LIBDIR=%{libdir}
    MANDIR=%{mandir}
    ETCDIR=%{sysconfdir}
    BUILD_STATIC_LIB=0
    user

config:
  install-commands:
  - |
    make -j1 install DESTDIR="%{install-root}" PREFIX="%{prefix}" SBINDIR="%{bindir}" BINDIR="%{bindir}" LIBDIR="%{libdir}" MANDIR="%{mandir}" ETCDIR="%{sysconfdir}"
  # sensors-detect --auto only saves its results when /etc/sysconfig exists:
  # it then writes /etc/sysconfig/lm_sensors and enables lm_sensors.service,
  # which loads the detected hwmon modules at boot. Ship the unit, create the
  # directory at boot, and keep the unit disabled until sensors-detect has
  # written its EnvironmentFile (it fails to start without one).
  - install -Dm644 prog/init/lm_sensors.service "%{install-root}%{indep-libdir}/systemd/system/lm_sensors.service"
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/tmpfiles.d/lm-sensors.conf"
    cat > "%{install-root}%{indep-libdir}/tmpfiles.d/lm-sensors.conf" <<'EOF'
    d /etc/sysconfig 0755 root root -
    EOF
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-lm-sensors.preset"
    cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-lm-sensors.preset" <<'EOF'
    disable lm_sensors.service
    EOF
  - |
    %{install-extra}
