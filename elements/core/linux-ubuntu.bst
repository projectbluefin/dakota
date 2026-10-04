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
# Remote compilation, wired the way gnome-build-meta's include/recc.yml and
# include/gcc-for-recc.yml wire it: recc-wrapper puts recc-backed gcc/cc in
# /usr/recc/bin, and the staged gcc digest becomes the remote chroot.
- gnome-build-meta.bst:buildsystems/recc-wrapper.bst
- filename: freedesktop-sdk.bst:components/gcc.bst
  config:
    digest-environment: RECC_REMOTE_PLATFORM_chrootRootDigest

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
  # Ubuntu SAUCE in scripts/rust_is_available.sh and rust/Makefile derives
  # the Rust std source from `rustc --version` as /usr/src/rustc-<ver>/library
  # (Ubuntu's rust-src layout) instead of `rustc --print sysroot`. Point it at
  # freedesktop-sdk's rust-src, or RUST_IS_AVAILABLE=n silently drops RUST.
  RUST_LIB_SRC: '%{indep-libdir}/rustlib/src/rust/library'
  # recc sends each C compile (`gcc -c` on a .c file) through the sandbox's
  # remote-apis-socket as its own action, so Kbuild's compiles spread over
  # every remote-execution worker instead of this element's one action.
  # Everything recc does not support runs locally: links (vmlinux, modpost,
  # modules), `-E`/`-S` (asm-offsets, linker scripts, genksyms), stdin input
  # (Kconfig asm-goto probes), `-x assembler-with-cpp`, and rustc.
  PATH: /usr/recc/bin:/usr/bin:/bin:/usr/sbin:/sbin
  RECC_SERVER: unix:/tmp/casd.sock
  RECC_DEPS_GLOBAL_PATHS: 'true'
  RECC_NO_PATH_REWRITE: 'true'
  # Inputs that must compile locally:
  # - /dev/null: Kconfig and Kbuild cc-option probes. A remote failure there
  #   would silently drop a flag or flip a config symbol.
  # - *.S/*.s: several pull files in with `.incbin` (certs, initramfs,
  #   piggy, bootconfig, embedded cmdline), which recc's `-M` scan cannot see.
  # - kernel/configs.c, kernel/kheaders.c: `.incbin` from inline asm.
  RECC_INVALID_INPUT_PATHS_REGEX: '/dev/null,.*\.[sS],.*/kernel/configs\.c,.*/kernel/kheaders\.c'
  # Release the make jobserver slot while waiting on a remote compile, so
  # -j%{max-jobs} bounds local work, not remote compiles in flight.
  RECC_USE_JOBSERVER: 'true'
  RECC_USE_LOCALCAS: 'true'
  # Compile locally when the remote-apis socket cannot execute (no remote
  # execution configured, transport errors). Same command, same output.
  RECC_FALLBACK_TO_LOCAL: 'true'
  (?):
  - x86_64_v3:
      KCFLAGS: "-march=x86-64-v3 -mtune=skylake"

environment-nocache:
- MAXJOBS
- RECC_USE_JOBSERVER
- RECC_USE_LOCALCAS
- RECC_FALLBACK_TO_LOCAL

sandbox:
  remote-apis-socket:
    path: /tmp/casd.sock

config:
  configure-commands:
  - |
    make defconfig

  - |
    . ./config-utils.sh
    rm -f expected-configs
    . ./fdsdk-config.sh "%{arch}"

  - |
    . ./config-utils.sh
    enable CRYPTO_ZSTD
    . ./dakota-config.sh
    # Ship the C binder (as Ubuntu does): Rust binder depends on
    # !ANDROID_BINDER_IPC, so drop its expectation and track C binder /
    # binderfs instead. RUST itself stays expected (see RUST_LIB_SRC).
    sed -i '/^\(CONFIG_\)\{0,1\}ANDROID_BINDER_IPC_RUST$/d' expected-configs
    echo CONFIG_ANDROID_BINDER_IPC >> expected-configs
    echo CONFIG_ANDROID_BINDERFS >> expected-configs
    scripts/config --keep-case -e ANDROID_BINDER_IPC
    scripts/config --keep-case -e ANDROID_BINDERFS
    # Upstream x86_64_defconfig sets WERROR=y, but Ubuntu SAUCE does not
    # build warning-clean (e.g. unused cred_euidcmp() in
    # security/apparmor/audit.c); Ubuntu's own annotations ship WERROR=n.
    remove WERROR
  - |
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
