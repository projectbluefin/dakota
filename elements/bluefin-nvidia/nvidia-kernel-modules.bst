# Only the kernel modules from nvidia-drivers.bst, without its userspace or
# runtime dependencies. The NVIDIA boot layer carries these; the base
# compose excludes them.
kind: filter

build-depends:
- bluefin-nvidia/nvidia-drivers.bst

config:
  include:
  - kernel-modules
