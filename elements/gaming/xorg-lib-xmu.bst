# X miscellaneous utilities client library for gamescope.
# FDSDK 25.08 does not ship libXmu, but Valve/OGC gamescope links it.
kind: autotools

sources:
- kind: git_repo
  url: freedesktop:xorg/lib/libxmu.git
  track: libXmu-*
  ref: libXmu-1.3.1-0-gcdf280f6611932f79ab872832974e8043b1cad6d

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/xorg-util-macros.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/xorg-lib-x11.bst
- freedesktop-sdk.bst:components/xorg-lib-xext.bst
- freedesktop-sdk.bst:components/xorg-lib-xt.bst

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{libdir}/libXmu.so'
        - '%{libdir}/libXmuu.so'
