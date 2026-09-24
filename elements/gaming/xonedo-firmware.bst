# Xbox wireless-dongle firmware (Microsoft redistributable).
#
# Same payload Bazzite installs via xone-dongle-firmware / install/firmware.sh,
# but staged as pinned `remote` sources instead of curl-at-build-time: the
# upstream script hardcodes /lib/firmware, requires root + network, and takes
# no --destdir, none of which fits a hermetic BST sandbox. URLs, sha256, and
# cab-member names are taken verbatim from upstream install/firmware.sh
# (verified 2026-09-24 against xonedo @ 982cbcb); the PID rename
# (xone_dongle_<pid>.bin) reproduces the script's download_firmware().
kind: manual

sources:
- kind: remote
  url: https://catalog.s.download.windowsupdate.com/d/msdownload/update/driver/drvs/2017/03/2ea9591b-f751-442c-80ce-8f4692cdc67b_6b555a3a288153cf04aec6e03cba360afe2fce34.cab
  ref: 080ce4091e53a4ef3e5fe29939f51fd91f46d6a88be6d67eb6e99a5723b3a223
  filename: fw-02e6.cab
- kind: remote
  url: https://catalog.s.download.windowsupdate.com/c/msdownload/update/driver/drvs/2017/07/1cd6a87c-623f-4407-a52d-c31be49e925c_e19f60808bdcbfbd3c3df6be3e71ffc52e43261e.cab
  ref: 48084d9fa53b9bb04358f3bb127b7495dc8f7bb0b3ca1437bd24ef2b6eabdf66
  filename: fw-02fe.cab
- kind: remote
  url: https://catalog.s.download.windowsupdate.com/c/msdownload/update/driver/drvs/2017/06/1dbd7cb4-53bc-4857-a5b0-5955c8acaf71_9081931e7d664429a93ffda0db41b7545b7ac257.cab
  ref: 0023a7bae02974834500c665a281e25b1ba52c9226c84989f9084fa5ce591d9b
  filename: fw-02f9.cab
- kind: remote
  url: https://catalog.s.download.windowsupdate.com/d/msdownload/update/driver/drvs/2017/08/aeff215c-3bc4-4d36-a3ea-e14bfa8fa9d2_e58550c4f74a27e51e5cb6868b10ff633fa77164.cab
  ref: e2710daf81e7b36d35985348f68a81d18bc537a2b0c508ffdfde6ac3eae1bad7
  filename: fw-091e.cab

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:components/libarchive.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  build-commands:
  - |
    mkdir -p fw && cd fw
    bsdtar -xf ../fw-02e6.cab FW_ACC_00U.bin
    install -Dm644 FW_ACC_00U.bin %{install-root}/usr/lib/firmware/xone_dongle_02e6.bin
    bsdtar -xf ../fw-02fe.cab FW_ACC_00U.bin
    install -Dm644 FW_ACC_00U.bin %{install-root}/usr/lib/firmware/xone_dongle_02fe.bin
    bsdtar -xf ../fw-02f9.cab FW_ACC_CL.bin
    install -Dm644 FW_ACC_CL.bin %{install-root}/usr/lib/firmware/xone_dongle_02f9.bin
    bsdtar -xf ../fw-091e.cab FW_ACC_BR.bin
    install -Dm644 FW_ACC_BR.bin %{install-root}/usr/lib/firmware/xone_dongle_091e.bin
  install-commands:
  - |
    %{install-extra}
