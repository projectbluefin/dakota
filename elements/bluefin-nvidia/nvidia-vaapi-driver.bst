kind: meson
description: |
  VA-API driver backed by NVDEC (elFarto's nvidia-vaapi-driver, MIT).
  The .run only ships a VDPAU backend; Wayland apps and browsers decode
  through VA-API, so without this they fall back to software decode.
  Decode-only: NVENC encode is not exposed through VA-API.

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
# CUDA/NVDEC API headers; the libraries themselves (libcuda,
# libnvcuvid) are dlopened at runtime from nvidia-drivers.
- freedesktop-sdk.bst:components/nv-codec-headers.bst
# EGL headers + egl.pc: fdsdk's libglvnd is built with -Dheaders=false.
- freedesktop-sdk.bst:components/mesa-headers.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/libva.bst
- freedesktop-sdk.bst:components/libdrm.bst
# Bitstream parsing uses gstreamer-codecparsers-1.0 from plugins-bad.
- freedesktop-sdk.bst:components/gstreamer-plugins-bad.bst
- bluefin-nvidia/nvidia-drivers.bst

sources:
- kind: git_repo
  url: github:elFarto/nvidia-vaapi-driver.git
  track: '*'

  ref: v0.0.18-0-g982ba1c2464b9cea5a4403df8f2c5a351ca21394

config:
  install-commands:
    (>):
    - |
      set -euo pipefail
      # fdsdk libva.pc's driverdir is the full colon-separated search
      # path, and upstream meson uses it verbatim as install_dir. Move
      # the driver to the real driverdir and drop the mangled tree.
      driverdir="$(pkg-config --variable=driverdir libva)"
      if [ "${driverdir}" != "%{libdir}/dri" ]; then
          install -Dm755 \
              "%{install-root}${driverdir}/nvidia_drv_video.so" \
              "%{install-root}%{libdir}/dri/nvidia_drv_video.so"
          rm -rf "%{install-root}${driverdir%%:*}:"
      fi
