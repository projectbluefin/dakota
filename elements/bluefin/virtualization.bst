kind: stack

depends:
- gnome-build-meta.bst:core-deps/libvirt.bst
- gnome-build-meta.bst:core-deps/qemu.bst
# sdl2-compat only build-depends on SDL3, but dlopens it when QEMU starts.
# Keep this runtime dependency until the junction fixes sdl2-compat's closure.
- freedesktop-sdk.bst:components/sdl3.bst

public:
  bst:
    integration-commands:
    # The junction defaults to root-owned QEMU guests. Its sysusers file creates
    # a dedicated qemu account; use that without disabling AppArmor or device
    # isolation. Apply after staging to preserve the setting in both OCI variants.
    - printf '\n# Dakota system guests run unprivileged.\nuser = "qemu"\ngroup = "qemu"\n' >> /etc/libvirt/qemu.conf
