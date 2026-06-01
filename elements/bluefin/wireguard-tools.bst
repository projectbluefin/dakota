kind: manual

sources:
- kind: tar
  url: github_files:WireGuard/wireguard-tools/archive/refs/tags/v1.0.20260223.tar.gz
  ref: 859f8af03702db5e5c43f8ece77f5ebef40a2f4627c3e03997a031d4940ea9bc

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/libmnl.bst

config:
  build-commands:
  - |
    make -C src
  install-commands:
  - |
    make -C src install DESTDIR="%{install-root}" PREFIX="%{prefix}"
  - |
    %{install-extra}
