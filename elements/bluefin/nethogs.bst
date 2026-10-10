kind: meson

sources:
- kind: git_repo
  url: github:raboof/nethogs.git
  track: v*
  ref: v0.9.0-0-g2d5e96c5af8edc9dbdfa61ca71464f636a2af291
- kind: patch
  path: patches/nethogs/0001-determine-version.patch

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/pkg-config.bst
- gnome-build-meta.bst:core-deps/libpcap.bst
- freedesktop-sdk.bst:bootstrap/ncurses.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- gnome-build-meta.bst:core-deps/libpcap.bst
- freedesktop-sdk.bst:bootstrap/ncurses.bst

variables:
  meson-local: >-
    -Denable-libnethogs=disabled
    -Denable-nethogs-app=enabled

# Mission Center's setup script setcaps nethogs at runtime, which fails on
# bootc's read-only /usr. Bake the same caps at image build time; prepare-image
# runs initial scripts under fakecap so the xattr lands in the OCI layer (same
# mechanism as shadow's newuidmap). World-executable by design (#1725).
public:
  initial-script:
    script: |
      #!/bin/bash
      sysroot="${1}"
      setcap cap_net_admin,cap_net_raw,cap_dac_read_search,cap_sys_ptrace+pe "${sysroot}%{bindir}/nethogs"
