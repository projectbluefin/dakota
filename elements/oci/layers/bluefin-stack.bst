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
      # Delete the hwdb cache the SDK ships so systemd-hwdb, which integrates
      # last, writes a new file instead of replacing an existing one.
      #
      # Replacing is the only path that needs /proc: systemd links its
      # O_TMPFILE into place, gets EEXIST, and reopens the fd through
      # /proc/self/fd to compare inodes. BuildBarn's bb_runner chroots into the
      # action's input root without a procfs, and systemd reports a missing
      # /proc as ENOSYS (proc_fd_enoent_errno(), src/basic/fd-util.c), so the
      # image build died on the fully generic:
      #   Failed to write database /usr/lib/udev/hwdb.bin: Function not implemented
      # Creating the file fresh takes linkat(AT_EMPTY_PATH), which needs no
      # /proc. The command below regenerates it either way, so the image keeps
      # the same hwdb.bin it always had.
      #
      # Remove this once bb_runner gives actions a procfs
      # (bb-remote-execution#115).
      - rm -f /usr/lib/udev/hwdb.bin

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
