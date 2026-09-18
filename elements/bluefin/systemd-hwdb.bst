# gnome-build-meta's core-deps/systemd-hwdb.bst, replaced to delete the shipped
# database before regenerating it.
#
# freedesktop-sdk's components/systemd-hwdb.bst builds hwdb.bin at build time
# and ships it in its artifact. This element's integration command then
# regenerates it over that staged copy, and replacing an existing file is the
# one path in systemd-hwdb that needs /proc: it writes an O_TMPFILE, links it
# into place, gets EEXIST, and reopens the fd through /proc/self/fd to compare
# inodes. BuildBarn's bb_runner chroots into the action's input root without a
# procfs, and systemd reports a missing /proc as ENOSYS
# (proc_fd_enoent_errno(), src/basic/fd-util.c), so every image build died on:
#
#   Failed to write database /usr/lib/udev/hwdb.bin: Function not implemented
#
# A probe in the lab separated the two paths: in a chroot with no /proc,
# linkat(AT_EMPTY_PATH) into a free name succeeds, and only the replace path
# fails. Removing the file first keeps systemd-hwdb on the path that works.
#
# The removal has to live here rather than in a dakota element, because
# BuildStream integrates a junction's elements before the local project's: a
# command in oci/layers/bluefin-stack.bst runs at position 817 of the
# integration order and systemd-hwdb's at 606 (bst show --deps run). Same
# element, same list, so the order is guaranteed.
#
# The regenerated database is identical either way, so the image is unchanged.
# Drop this override once bb_runner gives each action a procfs
# (bb-remote-execution#115).
kind: stack

public:
  bst:
    integration-commands:
    - rm -f /usr/lib/udev/hwdb.bin
    - systemd-hwdb --usr update
