# liblxc runtime for Incus system containers. The CLI and templates are omitted.
kind: meson

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/pkg-config.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/libcap.bst
- freedesktop-sdk.bst:components/libseccomp.bst
- freedesktop-sdk.bst:components/libapparmor.bst
- freedesktop-sdk.bst:components/openssl.bst
- freedesktop-sdk.bst:components/dbus.bst

variables:
  meson-local: >-
    -Dtests=false
    -Dexamples=false
    -Dman=false
    -Dtools=false
    -Dcommands=false
    -Dseccomp=true
    -Dapparmor=true
    -Dselinux=false
    -Dcapabilities=true
    -Dinstall-init-files=false
    -Dspecfile=false

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{libdir}/liblxc.so'

config:
  install-commands:
    (>):
    - install -Dm644 COPYING LICENSE.LGPL2.1 LICENSE.GPL2 -t "%{install-root}%{datadir}/licenses/lxc"

sources:
- kind: git_repo
  url: github:lxc/lxc.git
  track: v6.0.*
  exclude:
  - '*rc*'
  ref: v6.0.6-0-ge3a3f7066a01024bbf68319447ac7c6e5b20e94b
