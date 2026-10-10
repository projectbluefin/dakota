kind: manual
description: |
  gVisor runsc OCI runtime and containerd shim, from the upstream release
  (release-20260928.0). Used as a sandboxed container runtime.

sources:
- kind: tar
  base-dir: ''
  (?):
  - arch == "x86_64":
      url: gvisor:releases/release/20260928/x86_64/gvisor.tar.bz2
      ref: f3ed9131bc252259df150e270154180188f9df56b73a2312940325e1f522a2d6
  - arch == "aarch64":
      url: gvisor:releases/release/20260928/aarch64/gvisor.tar.bz2
      ref: b7e11d27cbd69370ed7addb6c0d1c33e70e57a153cee57b5fdc5344bf303c7eb
- kind: remote
  url: github-raw:google/gvisor/release-20260928.0/LICENSE
  ref: 0fbab5c58efbdf6d31e8085214f2dd821659c03d73cff3ed2b08e98826ea1cd9
  filename: LICENSE

build-depends:
- core/sandbox-tools.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - install -Dm755 runsc "%{install-root}%{bindir}/runsc"
  - install -Dm755 containerd-shim-runsc-v1 "%{install-root}%{bindir}/containerd-shim-runsc-v1"
  # runsc execs its sidecars from gvisor-bin/ next to itself.
  - |
    for f in gvisor-bin/*; do
      install -Dm755 "$f" "%{install-root}%{bindir}/$f"
    done
  - install -Dm644 LICENSE "%{install-root}%{datadir}/licenses/gvisor/LICENSE"
