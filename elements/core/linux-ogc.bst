# Open Gaming Collective (OGC) kernel for Dakota gaming variants, selected
# via the junction override in elements/freedesktop-sdk.bst. Reproduces
# FDSDK's artifact contract exactly: vmlinuz/config at %{bootdir}, modules at
# /usr/lib/modules/<kver>/ with a `build` symlink into
# /usr/src/linux-<kver> (nvidia-drivers.bst compiles against it).
#
# The recipe is FDSDK 25.08 components/linux.bst with three deltas:
#   1. Source: OGC's stable-tree fork; FDSDK's patch queue is dropped,
#      the OGC tree carries its own gaming patchset.
#   2. Config: FDSDK's fdsdk-config.sh pass (vendored at files/linux/,
#      keep in sync when bumping the junction), then
#      OGC's ogc.config.set/unset fragments (sched_ext, ntsync, BTF).
#   3. Modules stripped (INSTALL_MOD_STRIP=1) and vmlinux to the devel
#      split: OGC forces DEBUG_INFO=y for BTF.
#
# Bumps: `just bst source track core/linux-ogc.bst` follows stable v7.1.8-ogc*
# tags while testing remains on the common 7.1.8 baseline; update the
# ogc-localversion variable to match the new tag. On a
# stable-series jump, nvidia-drivers.bst must compile against the new
# tree before shipping.
kind: make
description: OGC Linux kernel (Dakota gaming variants)

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
# Provides /keys/linux-module-cert.crt; fdsdk-config.sh wires it into
# SYSTEM_TRUSTED_KEYS when present.
- filename: freedesktop-sdk.bst:components/linux-module-cert.bst
  strict: true

variables:
  # OGC patchset revision of the pinned tag; keep in sync with the
  # `ref:` under sources (v<kver>-ogcN-...). Not derivable at build
  # time: the tree ships no EXTRAVERSION or localversion files.
  ogc-localversion: '-ogc4'
  bootdir: /boot
  indep-libdir: '%{prefix}/lib'
  # Modules are stripped by kbuild (INSTALL_MOD_STRIP=1) *before* the
  # module signature is appended; a post-build strip pass would tear
  # the signatures off again.
  strip-binaries: ''
  kernel_arch: '%{arch}'
  src-arch: '%{kernel_arch}'
  image-name: '$(make -s image_name)'
  (?):
  - arch == "x86_64":
      src-arch: x86
  - arch == "aarch64":
      kernel_arch: arm64

environment:
  ARCH: '%{kernel_arch}'
  # compile.h has hardcoded timestamp, let's seed it
  KBUILD_BUILD_TIMESTAMP: 'Thu Nov 10 15:00:00 UTC 2011'
  KBUILD_BUILD_USER: 'tomjon'
  MAXJOBS: "%{max-jobs}"

environment-nocache:
- MAXJOBS

config:
  configure-commands:
  - |
    # Generate the default kernel config for the target architecture
    make defconfig

  - |
    . ./config-utils.sh
    rm -f expected-configs
    . ./fdsdk-config.sh "%{arch}"

  - |
    # Layer the OGC gaming fragments over the FDSDK config. Format:
    # ogc.config.set holds CONFIG_X=y|m|"str"|<int> lines, unset holds
    # bare CONFIG names. Options whose dependencies aren't met on this
    # config are dropped by olddefconfig below, same as OGC's own
    # cross-distro packaging.
    while IFS= read -r line; do
      case "$line" in ''|'#'*) continue ;; esac
      name=${line%%=*}
      val=${line#*=}
      case "$val" in
        y) scripts/config --keep-case -e "$name" ;;
        m) scripts/config --keep-case -m "$name" ;;
        \"*\")
          val=${val#\"}; val=${val%\"}
          scripts/config --keep-case --set-str "$name" "$val"
          ;;
        *) scripts/config --keep-case --set-val "$name" "$val" ;;
      esac
    done < ogc.config.set
    while IFS= read -r name; do
      case "$name" in ''|'#'*) continue ;; esac
      scripts/config --keep-case -d "$name"
      # The fragment wins over FDSDK's pass: if fdsdk-config.sh marked
      # this option expected (module/enable), stop requiring it. FDSDK
      # records names without the CONFIG_ prefix; match both forms.
      sed -i "/^\(CONFIG_\)\{0,1\}${name#CONFIG_}\$/d" expected-configs
    done < ogc.config.unset
    # OGC's fragment enables the C binder (+ binderfs, which needs it);
    # the Rust binder FDSDK expects is mutually exclusive with it
    # (depends on !ANDROID_BINDER_IPC), so olddefconfig drops it.
    # Waydroid only needs *a* binder providing binder/hwbinder/vndbinder
    # -- swap the expectation to the C driver OGC configures.
    sed -i '/^\(CONFIG_\)\{0,1\}ANDROID_BINDER_IPC_RUST$/d' expected-configs
    echo CONFIG_ANDROID_BINDER_IPC >> expected-configs
    echo CONFIG_ANDROID_BINDERFS >> expected-configs
    # The gaming point of this kernel; fail the build if these regress.
    echo CONFIG_SCHED_CLASS_EXT >> expected-configs
    echo CONFIG_NTSYNC >> expected-configs

  - |
    # Stamp `uname -r` with the OGC revision (e.g. 7.1.4-ogc1).
    # kernelrelease drives the modules dir, build tree and NVIDIA
    # module build alike, so co-versioning holds.
    scripts/config --keep-case --set-str LOCALVERSION "%{ogc-localversion}"
    scripts/config --keep-case -d LOCALVERSION_AUTO

  - |
    # Dakota deltas go through config-utils.sh enable/module so they land in
    # expected-configs and the post-olddefconfig gate verifies they survived;
    # raw scripts/config calls would be silently droppable.
    . ./config-utils.sh

    # Keep fdsdk's expected SP800-90A DRBGs: linux 7.1 dropped the
    # RNG_DEFAULT select that used to switch this menu on, and with it
    # off olddefconfig discards the child options.
    enable CRYPTO_DRBG_MENU

    # The zswap.compressor=zstd karg needs the compressor built in, not =m.
    enable CRYPTO_ZSTD

    # The OGC tree is not WERROR-clean (their own packaging and Fedora both
    # build without it); keep -Werror off this kernel so benign warnings in
    # the gaming patchset don't fail the build.
    remove WERROR

    # Hardware-enablement deltas from the Fedora config audit (VM guests,
    # homelab HBAs, laptop camera/audio/input completion); shared with
    # linux-fdsdk.bst.
    . ./dakota-config.sh

  - |
    # Drop expectations for options this tree no longer offers (the
    # vendored fdsdk config pass targets an older kernel era). Gaming-
    # critical symbols are exempt: losing them must fail the build.
    find . -name 'Kconfig*' -exec grep -h '^\(menu\)\{0,1\}config ' {} + \
      | awk '{print $2}' | sort -u > .kconfig-symbols
    cp expected-configs expected-configs.orig
    while IFS= read -r cfg; do
      sym=${cfg#CONFIG_}
      case "$sym" in
        SCHED_CLASS_EXT|NTSYNC|ANDROID_BINDER_IPC|ANDROID_BINDERFS) continue ;;
      esac
      if ! grep -qx "$sym" .kconfig-symbols; then
        echo "note: pruning expectation for ${cfg} (absent from this tree)" 1>&2
        sed -i "/^\(CONFIG_\)\{0,1\}${sym}\$/d" expected-configs
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
    # Only fail for...
    case "%{arch}" in
      x86_64|aarch64)
        [ "${missing_configs}" = 0 ]
      ;;
    esac

    # has() accepts =m; the zswap karg requires =y.
    grep -q '^CONFIG_CRYPTO_ZSTD=y$' .config

  install-commands:
  - |
    install -Dm644 "%{image-name}" '%{install-root}%{bootdir}/vmlinuz'
    install -Dm644 vmlinux '%{install-root}%{bootdir}/vmlinux'
    install -Dm644 System.map '%{install-root}%{bootdir}/System.map'
    install -Dm644 .config '%{install-root}%{bootdir}/config'
    make -j1 INSTALL_MOD_PATH='%{install-root}%{prefix}' INSTALL_MOD_STRIP=1 modules_install

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
    for file in "${to_copy[@]}"
    do
      targetfile="${targetdir}/${file}"
      dir="$(dirname "${targetfile}")"
      [ -d "${dir}" ] || install -d "${dir}"
      cp -aT "${file}" "${targetfile}"
    done

    ln -sr "${targetdir}" "%{install-root}%{indep-libdir}/modules/${release}/build"

  (?):
  - arch == "aarch64":
      install-commands:
        (>):
        - |
          make -j1 INSTALL_DTBS_PATH='%{install-root}%{bootdir}/dtbs' dtbs_install

public:
  bst:
    split-rules:
      devel:
        (>):
        - '%{bootdir}/System.map'
        # DEBUG_INFO=y (forced by OGC for BTF) makes vmlinux ~0.5 GB;
        # runtime consumers (scx schedulers) read /sys/kernel/btf/vmlinux,
        # not this file, so keep it out of the composed images.
        - '%{bootdir}/vmlinux'

sources:
- kind: git_repo
  url: github:OpenGamingCollective/linux.git
  track: v7.2.1-ogc*
  ref: v7.2.1-ogc4-0-g14c028f83498b2900fecd0940a058a3ac0622afe
- kind: local
  path: files/linux/config-utils.sh
- kind: local
  path: files/linux/fdsdk-config.sh
- kind: local
  path: files/linux/dakota-config.sh
- kind: local
  path: files/linux-ogc/ogc.config.set
- kind: local
  path: files/linux-ogc/ogc.config.unset
