kind: manual

sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: ziglang:download/0.15.2/zig-x86_64-linux-0.15.2.tar.xz
      ref: 02aa270f183da276e5b5920b1dac44a63f1a49e55050ebde3aecc9eb82f93239
  - arch == "aarch64":
      url: ziglang:download/0.15.2/zig-aarch64-linux-0.15.2.tar.xz
      ref: 958ed7d1e00d0ea76590d27666efbf7a932281b3d7ba0c6b01b0ff26498f667f

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 zig "%{install-root}%{bindir}/zig"
    mkdir -p "%{install-root}%{libdir}/zig"
    cp -a lib/* "%{install-root}%{libdir}/zig/"
