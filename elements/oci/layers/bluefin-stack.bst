kind: stack

depends:
  - bluefin/deps.bst
  - oci/os-release.bst

  - freedesktop-sdk.bst:components/linux-firmware.bst
  - core/ntsync-modules-load.bst
  - gnome-build-meta.bst:gnomeos/initramfs/signed-modules.bst
  - gnome-build-meta.bst:oci/initramfs.bst

  - gnome-build-meta.bst:gnomeos-deps/bootc.bst
  - gnome-build-meta.bst:oci/integration/bootc-config.bst
  - freedesktop-sdk.bst:vm/config/useradd-default.bst
  - freedesktop-sdk.bst:vm/config/sudo.bst

# Gaming host stack + Flathub preinstalls, only with `-o gaming true`.
# Covers both variants: bluefin-nvidia-stack.bst depends on this stack.
(?):
- gaming == true:
    depends:
      (>):
      - gaming/deps.bst

public:
  bst:
    integration-commands:
      - rm -rfv /boot /run

      # Required for bootc to create the image
      - mkdir /boot
      - mkdir /run
      - mkdir /sysroot
      - mkdir /sysroot/ostree
      - ln -s sysroot/ostree ostree

      # Wipe /var (may contain build-time state) and all FHS dirs that should
      # be symlinks into /var, then recreate with the correct structure.
      # Relative symlinks (var/home not /var/home) match zirconium-hawaii and
      # are safer in chroot/deploy tooling flows.
      - rm -rfv /home /root /opt /mnt /srv /var
      # Mount points for bind mounts
      - mkdir /home /root /snap
      - mkdir -p /var/home /var/roothome /var/opt /var/mnt /var/srv /var/tmp
      - ln -s var/opt /opt
      - ln -s var/mnt /mnt
      - ln -s var/srv /srv
      - ln -s ../../var/usrlocal usr/local

      - touch /etc/machine-id
