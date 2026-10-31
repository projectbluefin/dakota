kind: autotools
description: |
  NFS client utilities (mount.nfs, mount.nfs4, umount.nfs, rpc.statd, sm-notify,
  nfsidmap, nfsconf, and systemd generator/units) supporting NFSv3 and NFSv4.

sources:
- kind: tar
  url: kernel_pub:linux/utils/nfs-utils/3.1.1/nfs-utils-3.1.1.tar.xz
  ref: 7dbc05eb8b32828b322872b759a62cb3979cb4118f344dd8616813d1390e84e0

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/rpcsvc-proto.bst
- freedesktop-sdk.bst:components/systemd.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/libtirpc.bst
- freedesktop-sdk.bst:components/libevent.bst
- freedesktop-sdk.bst:components/keyutils.bst
- freedesktop-sdk.bst:components/libcap.bst
- freedesktop-sdk.bst:components/libnl.bst
- freedesktop-sdk.bst:components/util-linux.bst
- freedesktop-sdk.bst:components/sqlite.bst
- freedesktop-sdk.bst:components/libxml2.bst
- bluefin/rpcbind.bst

variables:
  # Merged-usr layout (/usr/sbin -> bin): sbindir points to /usr/bin.
  # --disable-sbin-override stops Makefile from hardcoding sbindir=/sbin.
  conf-local: >-
    --sbindir=%{bindir}
    --disable-sbin-override
    --with-systemd=%{indep-libdir}/systemd/system
    --with-statedir=/var/lib/nfs
    --with-statduser=rpcuser
    --with-start-statd=%{bindir}/start-statd
    --enable-libmount-mount
    --enable-mount
    --enable-nfsv4
    --enable-uuid
    --enable-ipv6
    --enable-tirpc
    --disable-gss
    --disable-svcgss
    --disable-nfsv4server
    --disable-nfsdctl

config:
  install-commands:
    (>):
    - |
      # Install statd sysusers and tmpfiles so /var/lib/nfs is populated at boot
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/sysusers.d/nfs-utils.conf"
      cat > "%{install-root}%{indep-libdir}/sysusers.d/nfs-utils.conf" <<'EOF'
      u rpcuser 29 "RPC Service User" /var/lib/nfs
      EOF
    - |
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/tmpfiles.d/nfs-utils.conf"
      cat > "%{install-root}%{indep-libdir}/tmpfiles.d/nfs-utils.conf" <<'EOF'
      d /var/lib/nfs 0755 root root -
      d /var/lib/nfs/statd 0700 rpcuser rpcuser -
      d /var/lib/nfs/statd/sm 0700 rpcuser rpcuser -
      d /var/lib/nfs/statd/sm.bak 0700 rpcuser rpcuser -
      f /var/lib/nfs/statd/state 0600 rpcuser rpcuser -
      d /var/lib/nfs/rpc_pipefs 0755 root root -
      d /var/lib/nfs/v4recovery 0700 root root -
      EOF
    - |
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-nfs-client.preset"
      cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-nfs-client.preset" <<'EOF'
      enable nfs-client.target
      EOF
    - |
      # Clean up files created during make install in /var
      rm -rf "%{install-root}/var"
