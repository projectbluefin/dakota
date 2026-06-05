kind: manual
description: |
  NVIDIA Container Toolkit: nvidia-ctk + nvidia-cdi-hook for podman GPU
  passthrough via CDI. This is mirrored from and element in gnomeos-deps from
  gnome-build-meta this is from their master branch, not yet on the gnome-50
  branch we junction. it is vendored inline here until we can pull it directly.

  We do not ship nvidia-container-runtime or libnvidia-container.
  Podman reads /var/run/cdi/nvidia.yaml natively; the upstream-provided
  nvidia-cdi-refresh.path watches /lib/modules/*/modules.dep and
  /usr/bin/nvidia-ctk and re-runs `nvidia-ctk cdi generate` on driver or
  toolkit changes.

sources:
- kind: git_repo
  url: github:NVIDIA/nvidia-container-toolkit.git
  track: v*.*.*
  exclude:
  - "*rc*"
  ref: v1.19.0-0-gec7b4e2fa2caecad6d89be4a26029b831fe7503a

build-depends:
- freedesktop-sdk.bst:components/go.bst
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  local_ldflags: -Wl,-z,lazy

config:
  build-commands:
  - go build ./cmd/nvidia-ctk
  - go build ./cmd/nvidia-cdi-hook
  install-commands:
  - install -Dt %{install-root}%{bindir} -m755 nvidia-ctk nvidia-cdi-hook
  - |
    install -Dt %{install-root}%{indep-libdir}/systemd/system -m644 \
            deployments/systemd/nvidia-cdi-refresh.{service,path}
