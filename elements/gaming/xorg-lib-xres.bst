# X Resource extension client library for gamescope.
# FDSDK 25.08 does not ship libXres, but Valve/OGC gamescope links it.
kind: autotools

sources:
- kind: git_repo
  url: freedesktop:xorg/lib/libxres.git
  track: libXres-*
  ref: libXres-1.2.3-0-g30c789e5065f7af7d6a03c09e3ceb073ed810bdd

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/xorg-util-macros.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/xorg-lib-x11.bst
- freedesktop-sdk.bst:components/xorg-lib-xext.bst

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{libdir}/libXRes.so'
