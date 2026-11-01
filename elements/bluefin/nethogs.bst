kind: meson

sources:
- kind: git_repo
  url: github:raboof/nethogs.git
  track: v*
  ref: v0.9.0-0-g2d5e96c5af8edc9dbdfa61ca71464f636a2af291
- kind: local
  path: files/nethogs
  directory: dakota-nethogs

build-depends:
# determineVersion.sh stamps the version from `git describe --tags`.
- freedesktop-sdk.bst:components/git.bst
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/pkg-config.bst
- gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/libpcap.bst
- freedesktop-sdk.bst:bootstrap/ncurses.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- gnome-build-meta.bst:freedesktop-sdk-extra.bst:components/libpcap.bst
- freedesktop-sdk.bst:bootstrap/ncurses.bst

variables:
  meson-local: >-
    -Denable-libnethogs=disabled
    -Denable-nethogs-app=enabled

# Per-process network stats are an admin opt-in, mirroring Mission Center's
# pkexec setup on mutable distros. /usr/bin/nethogs ships without capabilities
# (`sudo nethogs` works). A second copy under a root-only libexec directory
# holds cap_net_raw, which is enough to capture and attribute the user's own
# traffic; cap_dac_read_search and cap_sys_ptrace (other users' processes) and
# cap_net_admin (promiscuous mode, never used by Mission Center) are withheld.
# usr-bin-nethogs.mount, disabled by preset, bind-mounts the copy over
# /usr/bin/nethogs; `ujust toggle-network-monitoring` enables it behind
# systemd's admin authentication.
config:
  install-commands:
    (>):
    - install -Dm755 "%{install-root}%{bindir}/nethogs" "%{install-root}%{libexecdir}/dakota-nethogs/nethogs"
    - install -Dm644 dakota-nethogs/usr-bin-nethogs.mount "%{install-root}%{indep-libdir}/systemd/system/usr-bin-nethogs.mount"
    - |
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-nethogs.preset"
      cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-nethogs.preset" <<'EOF'
      disable usr-bin-nethogs.mount
      EOF

# CAS artifacts keep neither directory modes nor xattrs; prepare-image runs
# initial scripts under fakecap so both land in the OCI layer (same mechanism
# as shadow's newuidmap).
public:
  initial-script:
    script: |
      #!/bin/bash
      set -eu
      sysroot="${1}"
      chmod 0700 "${sysroot}%{libexecdir}/dakota-nethogs"
      setcap cap_net_raw+ep "${sysroot}%{libexecdir}/dakota-nethogs/nethogs"
