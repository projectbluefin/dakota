# Minimal 32-bit GTK2 runtime libraries for Steam's ubuntu12_32 UI.
# Freedesktop SDK 25.08 no longer ships GTK2, but Steam still dlopens
# libgtk-x11-2.0.so.0 from the 32-bit client path.
kind: manual

sources:
- kind: remote
  url: debian:pool/main/g/gtk+2.0/libgtk2.0-0_2.24.33-2+deb12u1_i386.deb
  ref: 59b4a428b6f5b76a7e1038a209fc4d8aee7ddf58dfbcf2159cd524f99fabd9c2
  filename: libgtk2.0-0_2.24.33-2+deb12u1_i386.deb

build-depends:
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/binutils.bst
- freedesktop-sdk.bst:components/tar.bst
- freedesktop-sdk.bst:components/xz.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    mkdir -p deb data "%{install-root}/usr/lib/i386-linux-gnu"
    cd deb
    ar x ../libgtk2.0-0_2.24.33-2+deb12u1_i386.deb
    cd ..
    tar -xf deb/data.tar.xz -C data

    cp -a data/usr/lib/i386-linux-gnu/libgtk-x11-2.0.so* "%{install-root}/usr/lib/i386-linux-gnu/"
    cp -a data/usr/lib/i386-linux-gnu/libgdk-x11-2.0.so* "%{install-root}/usr/lib/i386-linux-gnu/"

public:
  bst:
    split-rules:
      runtime:
        (>):
        - /usr/lib/i386-linux-gnu/libgtk-x11-2.0.so*
        - /usr/lib/i386-linux-gnu/libgdk-x11-2.0.so*
