kind: manual

sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: docker_static:x86_64/docker-28.1.1.tgz
      ref: ff34bd799b5e4c3738a3b1a383cf4067c672add48c7203fcd003fcb0aacebc94
  - arch == "aarch64":
      url: docker_static:aarch64/docker-28.1.1.tgz
      ref: 836bbaea204251922ec4dc79dbe81e323ccedaa726efc01f62683f547d721871

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 -t "%{install-root}%{bindir}" \
      containerd containerd-shim-runc-v2 ctr runc \
      docker dockerd docker-init docker-proxy
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system/containerd.service" <<'UNIT'
    [Unit]
    Description=containerd container runtime
    After=network.target local-fs.target

    [Service]
    ExecStart=/usr/bin/containerd
    Delegate=yes
    KillMode=process
    Restart=always
    LimitNPROC=infinity
    LimitCORE=infinity
    LimitNOFILE=infinity
    TasksMax=infinity

    [Install]
    WantedBy=multi-user.target
    UNIT
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system/docker.service" <<'UNIT'
    [Unit]
    Description=Docker Application Container Engine
    After=network-online.target containerd.service
    Wants=network-online.target
    Requires=containerd.service

    [Service]
    ExecStart=/usr/bin/dockerd --containerd=/run/containerd/containerd.sock
    ExecReload=/bin/kill -s HUP $MAINPID
    Delegate=yes
    KillMode=process
    Restart=always
    LimitNPROC=infinity
    LimitCORE=infinity
    LimitNOFILE=infinity

    [Install]
    WantedBy=multi-user.target
    UNIT
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system/docker.socket" <<'UNIT'
    [Unit]
    Description=Docker Socket for the API

    [Socket]
    ListenStream=/var/run/docker.sock
    SocketMode=0660
    SocketGroup=docker

    [Install]
    WantedBy=sockets.target
    UNIT
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system-preset/80-containerd.preset" <<'PRESET'
    enable containerd.service
    PRESET
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system-preset/80-docker.preset" <<'PRESET'
    enable docker.socket
    PRESET
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/sysusers.d/docker.conf" <<'SYSUSERS'
    g docker -
    SYSUSERS
  - |
    %{install-extra}
