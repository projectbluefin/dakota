kind: manual

sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: github_files:ublue-os/uupd/releases/download/v1.4.0/uupd_Linux_x86_64.tar.gz
      ref: c7463f193cd35b92cde2ee05496501d6ac13808899bd26e17e027b7ee9ee1acc
  - arch == "aarch64":
      url: github_files:ublue-os/uupd/releases/download/v1.4.0/uupd_Linux_arm64.tar.gz
      ref: 90f493aceadc3ef1a5a5fecff6ce21873dfed13bdca5d5d684e7f97c077a6855
  base-dir: ""

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 -t "%{install-root}%{bindir}" uupd
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system/uupd.service" <<'SERVICE'
    [Unit]
    Description=Universal Blue Update Oneshot Service
    StartLimitBurst=3
    StartLimitIntervalSec=600

    [Service]
    Type=oneshot
    # DO NOT CHANGE ANYTHING BELOW UNLESS YOU KNOW WHAT YOU ARE DOING
    # --disable-module-distrobox matches production Bluefin (build_files/base/17-cleanup.sh)
    ExecStart=/usr/bin/uupd --disable-module-distrobox --log-level=debug --json
    # Restart on failure for edge cases like waking from suspend and wifi not connecting immediately
    Restart=on-failure
    RestartSec=60s
    # Set SELinux context unconfined because bootc requires some special perms for relabeling (install_t????)
    SELinuxContext=system_u:unconfined_r:unconfined_t:s0
    SERVICE
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system/uupd.timer" <<'TIMER'
    [Unit]
    Description=Auto Update System Timer For Universal Blue
    Wants=network-online.target

    [Timer]
    # Run daily at 4:00 AM
    OnCalendar=*-*-* 04:00:00

    # If the system was off/suspended at 4:00 AM, trigger immediately on resume/boot
    Persistent=true

    # Wait up to 15 minutes after triggering and Spreads the load on update servers (thundering herd protection).
    RandomizedDelaySec=15m

    [Install]
    WantedBy=timers.target
    TIMER
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system/uupd-manual.service" <<'MANUAL'
    [Unit]
    Description=Universal Blue Update Oneshot Service - Manual Activation
    StartLimitBurst=3
    StartLimitIntervalSec=600

    [Service]
    Type=oneshot
    # DO NOT CHANGE ANYTHING BELOW UNLESS YOU KNOW WHAT YOU ARE DOING
    ExecStart=/usr/bin/uupd --hw-check=false --json --log-level=debug
    # Restart on failure for edge cases like waking from suspend and wifi not connecting immediately
    Restart=on-failure
    RestartSec=60s
    # Set SELinux context unconfined because bootc requires some special perms for relabeling (install_t????)
    SELinuxContext=system_u:unconfined_r:unconfined_t:s0
    MANUAL
  - |
    install -Dm644 /dev/stdin "%{install-root}%{sysconfdir}/uupd/config.json" <<'CONFIG'
    {
        "checks": {
            "hardware": {
                "enable": true,
                "bat-min-percent": 20,
                "cpu-max-percent": 50,
                "mem-max-percent": 90,
                "net-max-bytes": 700000
            }
        },
        "modules": {
            "brew": {
                "disable": false
            },
            "distrobox": {
                "disable": false
            },
            "flatpak": {
                "disable": false
            },
            "system": {
                "disable": false
            }
        }
    }
    CONFIG
  - |
    install -Dm644 /dev/stdin "%{install-root}%{sysconfdir}/polkit-1/rules.d/uupd.rules" <<'RULES'
    polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units") {
            switch(action.lookup("unit")) {
                case "uupd.service":
                    return polkit.Result.YES;
                case "uupd-manual.service":
                    return polkit.Result.YES;
            }
        }
    })
    RULES
  - |
    %{install-extra}
