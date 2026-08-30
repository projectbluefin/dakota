# freedesktop-sdk stable kernel for non-gaming Dakota variants.
#
# This reproduces the x86_64/aarch64 recipe of the linux.bst element at
# Dakota's pinned freedesktop-sdk 26.08 ref (elements/components/linux.bst
# plus elements/include/linux.yml, with build-depends junction-prefixed).
# The vendored files/linux/ scripts and patches/linux/ queue are verbatim
# copies from that ref; re-sync all of them at every fdsdk bump.
#
# As of 26.08, upstream builds ATH12K, strips modules (INSTALL_MOD_STRIP=1),
# and splits vmlinux/System.map to the devel domain itself, so those former
# Dakota deltas are gone. One Dakota delta remains:
#   CRYPTO_ZSTD forced =y: the zswap.compressor=zstd karg
#   (bluefin/zswap-config.bst, all variants) needs the compressor
#   built in, not =m.
#
# Exit condition: only drop this element in favor of components/linux.bst
# if upstream ships CONFIG_CRYPTO_ZSTD=y (or zswap moves off the karg) and
# zswap is re-verified on a booted image.
kind: make
description: freedesktop-sdk stable Linux kernel with CRYPTO_ZSTD built in

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
  # Modules are stripped by kbuild (INSTALL_MOD_STRIP=1) *before* the
  # module signature is appended; a post-build strip pass would tear
  # the signatures off again.
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
  # compile.h has a hardcoded timestamp; seed it for reproducibility.
  KBUILD_BUILD_TIMESTAMP: 'Thu Nov 10 15:00:00 UTC 2011'
  KBUILD_BUILD_USER: 'tomjon'
  MAXJOBS: "%{max-jobs}"
  # arch/x86/Makefile hardcodes -march=x86-64 -mtune=generic, overriding
  # gcc's --with-arch_64 default. KCFLAGS is appended after KBUILD_CFLAGS,
  # so a later -march wins.
  (?):
  - x86_64_v3:
      KCFLAGS: "-march=x86-64-v3 -mtune=skylake"

environment-nocache:
- MAXJOBS

config:
  configure-commands:
  - |
    make defconfig

  - |
    . ./config-utils.sh
    rm -f expected-configs
    . ./fdsdk-config.sh "%{arch}"

  - |
    # The zswap.compressor=zstd karg needs the compressor built in, not =m.
    scripts/config --keep-case -e CRYPTO_ZSTD

  - |
    # Drop expectations for options this newer stable tree no longer offers.
    # Existing symbols whose dependencies are not met remain hard failures.
    find . -name 'Kconfig*' -exec grep -h '^\(menu\)\{0,1\}config ' {} + \
      | awk '{print $2}' | sort -u > .kconfig-symbols
    cp expected-configs expected-configs.orig
    while IFS= read -r cfg; do
      sym=${cfg#CONFIG_}
      if ! grep -qx "$sym" .kconfig-symbols; then
        echo "note: pruning expectation for ${cfg} (absent from this tree)" 1>&2
        sed -i "/^\(CONFIG_\)\{0,1\}${sym}$/d" expected-configs
      fi
    done < expected-configs.orig
    rm -f expected-configs.orig

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

    # has() accepts =m; the zswap karg requires =y.
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
        # DEBUG_INFO=y (via the shared config's DEBUG_INFO_BTF) makes
        # vmlinux ~0.5 GB; runtime consumers read /sys/kernel/btf/vmlinux,
        # not this file, so keep it out of the composed images.
        - '%{indep-libdir}/modules/*/vmlinux'
    overlap-whitelist:
    - "%{project_licensedir}"
    - "%{project_licensedir}/**"

sources:
- kind: git_repo
  url: kernel:linux/kernel/git/stable/linux.git
  track: v*
  exclude:
  - '*-rc*'
  ref: v7.2-0-g8d3ae59288f1e7d58d76558a6ee96d533bc5019f
- kind: patch_queue
  path: patches/linux
- kind: local
  path: files/linux/config-utils.sh
- kind: local
  path: files/linux/fdsdk-config.sh
