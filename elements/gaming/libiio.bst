# libiio runtime library needed by InputPlumber's upstream release binary.
#
# InputPlumber links libiio for handheld sensor/IMU paths. FDSDK 25.08 does
# not ship libiio, so build a small shared-library-only copy with network/USB
# daemons, bindings, docs, and tests disabled.
kind: cmake

sources:
- kind: git_repo
  url: github:analogdevicesinc/libiio.git
  track: v0.26
  ref: v0.26-0-ga0eca0d2bf10326506fb762f0eec14255b27bef5

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  cmake-local: >-
    -DBUILD_SHARED_LIBS=ON
    -DWITH_TESTS=OFF
    -DWITH_EXAMPLES=OFF
    -DWITH_NETWORK_BACKEND=OFF
    -DWITH_USB_BACKEND=OFF
    -DWITH_SERIAL_BACKEND=OFF
    -DWITH_IIOD=OFF
    -DWITH_LOCAL_BACKEND=ON
    -DWITH_XML_BACKEND=OFF
    -DWITH_ZSTD=OFF
    -DWITH_DOC=OFF
    -DWITH_MAN=OFF
    -DCPP_BINDINGS=OFF
    -DCSHARP_BINDINGS=OFF
    -DPYTHON_BINDINGS=OFF
    -DWITH_SYSTEMD=OFF
    -DINSTALL_UDEV_RULE=OFF
