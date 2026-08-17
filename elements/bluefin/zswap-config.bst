kind: manual
description: |
  Declarative kernel arguments and sysctl parameters to enable and optimize zswap.

  bootc applies the kernel arguments from /usr/lib/bootc/kargs.d/ on switch/upgrade.
  The vm.swappiness=100 sysctl instructs the kernel to treat anonymous and file-backed
  memory with parity, routing swap I/O through high-speed zswap cache.

  No zswap.zpool karg: kernel 7.x removed the parameter (zsmalloc is the only
  backend). The backing swap device zswap fronts is provided by
  bluefin/swapfile.bst; zram is disabled via an integration command in
  oci/layers/bluefin-stack.bst.

build-depends:
- core/sandbox-tools.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    install -d "%{install-root}/usr/lib/bootc/kargs.d"
    cat > "%{install-root}/usr/lib/bootc/kargs.d/20-zswap.toml" <<'EOF'
    kargs = [
        "zswap.enabled=1",
        "zswap.compressor=zstd",
        "zswap.max_pool_percent=20",
        "zswap.shrinker_enabled=1",
    ]
    EOF

  - |
    install -d "%{install-root}/usr/lib/sysctl.d"
    cat > "%{install-root}/usr/lib/sysctl.d/60-swappiness.conf" <<'EOF'
    vm.swappiness = 100
    EOF
