kind: autotools
description: |
  Universal addresses to RPC program number mapper (rpcbind and rpcinfo),
  required for NFSv3 mounts and NSM locking (rpc.statd).

sources:
- kind: tar
  url: sourceforge:project/rpcbind/rpcbind/1.2.7/rpcbind-1.2.7.tar.bz2
  ref: f6edf8cdf562aedd5d53b8bf93962d61623292bfc4d47eedd3f427d84d06f37e

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/pkg-config.bst
- freedesktop-sdk.bst:components/systemd.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/libtirpc.bst
- freedesktop-sdk.bst:components/systemd-libs.bst

variables:
  # Merged-usr layout (/usr/sbin -> bin): install rpcbind into /usr/bin so it
  # does not replace the /usr/sbin symlink at compose time.
  conf-local: >-
    --sbindir=%{bindir}
    --enable-warmstarts
    --with-statedir=/run/rpcbind
    --with-rpcuser=rpc
    --with-nss-modules="files usrfiles"
    --with-systemdsystemunitdir=%{indep-libdir}/systemd/system

config:
  install-commands:
    (>):
    - |
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/sysusers.d/rpcbind.conf"
      cat > "%{install-root}%{indep-libdir}/sysusers.d/rpcbind.conf" <<'EOF'
      u rpc 32 "Rpcbind Daemon" /var/lib/rpcbind
      EOF
    - |
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/tmpfiles.d/rpcbind.conf"
      cat > "%{install-root}%{indep-libdir}/tmpfiles.d/rpcbind.conf" <<'EOF'
      d /run/rpcbind 0700 rpc rpc -
      EOF
    - |
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-rpcbind.preset"
      cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-rpcbind.preset" <<'EOF'
      disable rpcbind.service
      disable rpcbind.socket
      EOF
