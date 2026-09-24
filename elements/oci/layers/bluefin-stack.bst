kind: stack

depends:
  - bluefin/deps.bst
  - oci/os-release.bst

  - freedesktop-sdk.bst:components/linux-firmware.bst
  - core/ntsync-modules-load.bst
  - gnome-build-meta.bst:gnomeos/initramfs/signed-modules.bst
  - gnome-build-meta.bst:oci/initramfs/image.bst

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
      # Overwrite the zram-generator config from gnomeos-deps/zram-generator.bst.
      # An element-level override loses the staging-order overlap (see
      # .agents/skills/dakota-buildstream/SKILL.md); integration commands run after all staging,
      # so this is the deterministic winner. No [zramN] section = no zram device.
      - printf '# zram disabled; Dakota swaps via zswap + /var/swap/swapfile\n' > /usr/lib/systemd/zram-generator.conf

      - rm -rfv /boot /run

      # Required for bootc to create the image
      - mkdir /boot
      - mkdir /run
      - mkdir /sysroot
      - mkdir /sysroot/ostree

      # Remove link paths first: ln -s nests inside an existing directory.
      - rm -rfv /home /root /opt /mnt /srv /var /ostree /usr/local
      # Mount points for bind mounts
      - mkdir /home /root /snap
      - mkdir -p /var/home /var/roothome /var/opt /var/mnt /var/srv /var/tmp
      # Relative targets: bootc container lint rejects absolute ones.
      - ln -sT sysroot/ostree /ostree
      - ln -sT var/opt /opt
      - ln -sT var/mnt /mnt
      - ln -sT var/srv /srv
      - ln -sT ../var/usrlocal /usr/local

      - touch /etc/machine-id
