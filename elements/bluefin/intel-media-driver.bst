kind: manual
description: Intel VA-API driver (iHD) for host apps; fdsdk ships it only as a Flatpak extension.

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

depends:
- freedesktop-sdk.bst:extensions/platform-vaapi-intel/intel-media-driver.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    # libigdgmm lives beside the driver, outside the default linker path.
    install -Dm644 /dev/null "%{install-root}%{sysconfdir}/ld.so.conf.d/intel-vaapi-driver.conf"
    printf '%s\n' "%{libdir}/dri/intel-vaapi-driver/lib" \
        > "%{install-root}%{sysconfdir}/ld.so.conf.d/intel-vaapi-driver.conf"
