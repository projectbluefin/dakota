# Complete GCC + GNU Make closure used only as input to the host-toolchain
# filter. Keeping this separate lets the final image retain development files
# without composing the complete OS twice.
kind: compose

build-depends:
- freedesktop-sdk.bst:components/gcc.bst
- freedesktop-sdk.bst:components/make.bst

config:
  integrate: false
  exclude:
  - debug
  - extra
  - static-blocklist

public:
  bst:
    split-rules:
      # Compiler drivers and the assembler/linker tools they invoke.
      host-toolchain:
      - /etc/gprofng.rc
      - /usr/bin/*gcc*
      - /usr/bin/g++*
      - /usr/bin/c++
      - /usr/bin/c++filt
      - /usr/bin/cc
      - /usr/bin/cpp
      - /usr/bin/gcov*
      - /usr/bin/gfortran*
      - /usr/bin/lto-dump
      - /usr/bin/make
      - /usr/bin/ncurses*-config
      - /usr/bin/pcre2-config
      - /usr/bin/addr2line
      - /usr/bin/ar
      - /usr/bin/as
      - /usr/bin/elfedit
      - /usr/bin/eu-*
      - /usr/bin/gp-*
      - /usr/bin/gprof*
      - /usr/bin/ld*
      - /usr/bin/nm
      - /usr/bin/objcopy
      - /usr/bin/objdump
      - /usr/bin/ranlib
      - /usr/bin/readelf
      - /usr/bin/size
      - /usr/bin/strings
      - /usr/bin/strip
      - /usr/bin/*-unknown-linux-gnu-*

      # Headers, compiler internals, startup objects, linker inputs, and
      # development metadata required by ordinary Homebrew source builds.
      - /usr/include
      - /usr/include/**
      - /usr/lib/gcc
      - /usr/lib/gcc/**
      - /usr/libexec/gcc
      - /usr/libexec/gcc/**
      - /usr/*-unknown-linux-gnu
      - /usr/*-unknown-linux-gnu/**
      - '%{libdir}/*.a'
      - '%{libdir}/*.o'
      - '%{libdir}/*.so'
      - '%{libdir}/*.spec'
      - '%{libdir}/bfd-plugins'
      - '%{libdir}/bfd-plugins/**'
      - '%{libdir}/gprofng'
      - '%{libdir}/gprofng/**'
      - '%{libdir}/libcc1.so*'
      - '%{libdir}/libctf*.so*'
      - '%{libdir}/libgprofng.so*'
      - '%{libdir}/libsframe.so*'
      - '%{libdir}/pkgconfig'
      - '%{libdir}/pkgconfig/**'
      - '%{libdir}/bash'
      - '%{libdir}/bash/**'
      - '%{libdir}/libstdc++.modules.json'

      # Keep the corresponding documentation, translations, and license text.
      - /usr/share/gcc-*
      - /usr/share/gcc-*/**
      - /usr/share/gdb/auto-load
      - /usr/share/gdb/auto-load/**
      - /usr/share/info
      - /usr/share/info/**
      - /usr/share/locale
      - /usr/share/locale/**
      - /usr/share/man
      - /usr/share/man/**
      - /usr/share/licenses/freedesktop-sdk/binutils
      - /usr/share/licenses/freedesktop-sdk/binutils/**
      - /usr/share/licenses/freedesktop-sdk/gcc
      - /usr/share/licenses/freedesktop-sdk/gcc/**
      - /usr/share/licenses/freedesktop-sdk/make
      - /usr/share/licenses/freedesktop-sdk/make/**
      - /usr/share/licenses/freedesktop-sdk/linux
      - /usr/share/licenses/freedesktop-sdk/linux/**

      # The runtime stack owns the installed debuginfod implementation. Its
      # versioned module happens to end in .so, but is not a linker input.
      runtime-authoritative:
      - /usr/include/elfutils/debuginfod.h
      - '%{libdir}/libdebuginfod.so'
      - '%{libdir}/libdebuginfod-*.so'
