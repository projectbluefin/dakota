kind: make

sources:
- kind: git_repo
  url: github:sadko4u/lsp-plugins.git
  track: lsp-plugins-1.1.*
  ref: lsp-plugins-1.1.26-0-gad2720345ce5dffb45f871146de1ae6d16f4c73d

variables:
  make-args: >-
    BUILD_MODULES=lv2
    LV2_UI=0
    BUILD_R3D_BACKENDS=
    PREFIX=%{prefix}

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
- freedesktop-sdk.bst:components/pkg-config.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/sndfile.bst
