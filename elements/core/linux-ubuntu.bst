# Ubuntu 24.04 (Noble) kernel element tracking Ubuntu's official source.
#
# Reproduces Dakota's standard kernel artifact contract:
# - vmlinuz/vmlinux/System.map/config under /usr/lib/modules/<kver>/
# - module tree under /usr/lib/modules/<kver>/
# - build symlink pointing to /usr/src/linux-<kver>
# - CRYPTO_ZSTD=y built-in for zswap.compressor=zstd karg
kind: make
description: Ubuntu Linux kernel for Dakota

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
- freedesktop-sdk.bst:components/bison.bst
- freedesktop-sdk.bst:components/cpio.bst
- freedesktop-sdk.bst:components/flex.bst
- freedesktop-sdk.bst:components/bc.bst
- freedesktop-sdk.bst:components/gzip.bst
- freedesktop-sdk.bst:components/pahole.bst
- freedesktop-sdk.bst:components/python3.bst
- freedesktop-sdk.bst:components/rsync.bst
- freedesktop-sdk.bst:components/rust.bst
- freedesktop-sdk.bst:components/rust-bindgen.bst
- freedesktop-sdk.bst:components/rust-src.bst
- freedesktop-sdk.bst:components/util-linux.bst
- freedesktop-sdk.bst:components/zstd.bst
- filename: freedesktop-sdk.bst:components/linux-module-cert.bst
  strict: true

variables:
  indep-libdir: '%{prefix}/lib'
  strip-binaries: ''
  kernel_arch: '%{arch}'
  src-arch: '%{kernel_arch}'
  image-name: '$(make -s image_name)'
  optimize-debug: false
  (?):
  - arch == "x86_64":
      src-arch: x86
  - arch == "aarch64":
      kernel_arch: arm64

environment:
  ARCH: '%{kernel_arch}'
  KBUILD_BUILD_TIMESTAMP: 'Thu Nov 10 15:00:00 UTC 2011'
  KBUILD_BUILD_USER: 'tomjon'
  MAXJOBS: "%{max-jobs}"
  (?):
  - x86_64_v3:
      KCFLAGS: "-march=x86-64-v3 -mtune=skylake"

environment-nocache:
- MAXJOBS

config:
  configure-commands:
  - |
    # Export Ubuntu kernel .config from debian.master/config/annotations
    case "%{arch}" in
      x86_64)  u_arch=amd64 ;;
      aarch64) u_arch=arm64 ;;
      *)       u_arch="%{arch}" ;;
    esac
    debian/scripts/misc/annotations --file debian.master/config/annotations --arch "$u_arch" --flavour generic --export > .config

  - |
    . ./config-utils.sh
    rm -f expected-configs
    # Force CRYPTO_ZSTD=y for zswap.compressor=zstd karg
    enable CRYPTO_ZSTD
    # Apply Dakota hardware and VM enablement options
    . ./dakota-config.sh

  - |
    make -j1 olddefconfig

  - |
    . ./config-utils.sh

    missing_configs=0
    for config in $(cat expected-configs); do
      if ! has "${config}"; then
        echo "Missing ${config}" 1>&2
        missing_configs=1
      fi
    done
    case "%{arch}" in
      x86_64|aarch64)
        [ "${missing_configs}" = 0 ]
      ;;
    esac

    grep -q '^CONFIG_CRYPTO_ZSTD=y$' .config

  install-commands:
  - |
    release=$(make -s kernelrelease)
    install -Dm644 "%{image-name}" "%{install-root}%{indep-libdir}/modules/${release}/vmlinuz"
    install -Dm644 vmlinux "%{install-root}%{indep-libdir}/modules/${release}/vmlinux"
    install -Dm644 System.map "%{install-root}%{indep-libdir}/modules/${release}/System.map"
    install -Dm644 .config "%{install-root}%{indep-libdir}/modules/${release}/config"
    ZSTD_CLEVEL=19 make -j1 INSTALL_MOD_PATH="%{install-root}%{prefix}" INSTALL_MOD_STRIP=1 modules_install

  - |
    release=$(make -s kernelrelease)
    targetdir="%{install-root}%{prefix}/src/linux-${release}"

    rm "%{install-root}%{indep-libdir}/modules/${release}"/build

    to_copy=(
      Makefile
      Module.symvers
      .config
      "arch/%{src-arch}/include"
      "arch/%{src-arch}/Makefile"
      scripts
      include
    )
    if [ "$(scripts/config -s OBJTOOL)" = y ]; then
      to_copy+=(tools/objtool/objtool)
    fi
    for file in "${to_copy[@]}"; do
      targetfile="${targetdir}/${file}"
      dir="$(dirname "${targetfile}")"
      [ -d "${dir}" ] || install -d "${dir}"
      cp -aT "${file}" "${targetfile}"
    done

    ln -sr "${targetdir}" "%{install-root}%{indep-libdir}/modules/${release}/build"

  - |
    %{install-extra}

  (?):
  - arch == "aarch64":
      install-commands:
        (>):
        - |
          release=$(make -s kernelrelease)
          make -j1 INSTALL_DTBS_PATH="%{install-root}%{indep-libdir}/modules/${release}/dtbs" dtbs_install

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{indep-libdir}/modules/*/System.map'
        - '%{indep-libdir}/modules/*/vmlinux'
    overlap-whitelist:
    - "%{project_licensedir}"
    - "%{project_licensedir}/**"

sources:
- kind: git_repo
  url: https://git.launchpad.net/~ubuntu-kernel/ubuntu/+source/linux/+git/stonking
  track: Ubuntu-7.3.0-*
  ref: Ubuntu-7.3.0-8.8-0-g664a2f84fd2459e2cdd2b0eed45a89bfee3776ef
- kind: local
  path: files/linux/config-utils.sh
- kind: local
  path: files/linux/fdsdk-config.sh
- kind: local
  path: files/linux/dakota-config.sh
