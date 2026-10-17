kind: meson

sources:
- kind: git_repo
  url: kernel:libs/libtrace/libtracefs.git
  track: libtracefs-*
  ref: libtracefs-1.8.3-0-g6fad6a14ba0d4c4b437d9e4eed7098d4bb07b4fc

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/bison.bst
- freedesktop-sdk.bst:components/flex.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/libtraceevent.bst

variables:
  meson-local: >-
    -Ddoc=false
    -Dsamples=false
    -Dutest=false

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{libdir}/libtracefs.so'

config:
  install-commands:
    (>):
    - install -Dm644 LICENSES/LGPL-2.1 "%{install-root}%{datadir}/licenses/libtracefs/LGPL-2.1"
