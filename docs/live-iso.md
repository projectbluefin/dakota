# Live ISO

The live ISO boots the image's own kernel into a desktop session and installs
by moving that running session onto the target disk. There is no separate
installer environment and no restart between "live" and "installed".

Everything it needs is in this repository: `elements/iso/` and
`files/live-iso/`.

## How it works

The ISO has two partitions, written by `systemd-repart --el-torito=yes`, so
the same file boots as a USB stick and as an optical disc.

| Partition | Content |
|---|---|
| ESP (`DAKOTA`) | The image's boot chain, kernel and initramfs, one loader entry, a small extra initramfs with the live hook, and the Secure Boot certificate for enrolment |
| Seed (`dakota-live`) | A btrfs seed filesystem laid out like a bootc composefs install: the composefs repository, `state/deploy/<id>/` and `/var` |

1. **Live boot.** The loader entry carries `dakota.live` and an optional
   composefs digest (`composefs.digest=?...`), because the seed has no
   fs-verity. The initramfs hook adds a zram device to the read-only seed, so
   the root is writable in memory.
2. **Install.** The installer partitions the disk (ESP plus a root partition,
   by default LUKS sealed to the TPM), adds the root device to the live
   filesystem and removes the zram device and the seed. btrfs moves the data while the session keeps
   running.
3. **Finish.** fs-verity is turned on for every object, the installed loader
   entry requires it, and the live user, automatic login and installer files
   are scheduled for removal at the next boot.

Units that must not run in the live session (updates, Flatpak preinstall, ESP
automounts) are masked through `systemd.mask=` on the live loader entry.

## Building

```bash
just iso                  # from oci/bluefin.bst, for pull requests and local work
just iso IMAGE ORIGIN     # from an exported or published image, for releases
```

Both write `dakota-live.iso`, `dakota-live.json` and
`dakota-live.repart.json` to `.build-iso/`.

`IMAGE` is anything skopeo reads; `ORIGIN` is the reference the installed
system updates from:

```bash
just iso docker://ghcr.io/projectbluefin/dakota:testing ghcr.io/projectbluefin/dakota:testing
```

Release ISOs use the second form. The image BuildStream produces is not the
published one: `just export` squashes it, stamps the version and re-chunks
it. An ISO built from `oci/bluefin.bst` therefore installs a system with
`VERSION_ID=0` whose first update replaces the whole image. Built from the
published image, the installed system is that image, and `bootc upgrade
--check` reports no changes.

In both forms BuildStream supplies the tools: `iso/tools.bst` holds
everything `files/live-iso/build.py` runs. `iso/live.bst` builds with it;
the second form opens it as a sandbox with `bst shell`.

`iso/live.bst` keeps the composefs repository in the sandbox's tmpfs,
because the importer needs `O_TMPFILE` and the build sandbox's root does not
provide it. That build needs about 9 GB of RAM. The second form writes to
`.build-iso/` on disk.

## Limits the build enforces

- **ESP at most 256 MiB.** Firmware that boots the ESP from an optical disc
  can fail above that. The build stops and names the initramfs size when the
  boot files do not fit.
- **No unused space in the seed.** `check-seed.py` runs `btrfs check` on the
  seed and stops the build when the image holds more than 1 GiB that nothing
  uses. The shrink only cuts the image off after its last chunk, so the
  saving from the patch below can be lost without any error.
- **Seed compression.** The default zstd level packs the seed in about a
  minute. `SEED_ZSTD_LEVEL=15` makes the ISO about 0.3 GB smaller and takes
  about eight minutes longer.

## The installer

`iso/installer.bst` builds the installer (a D-Bus service and a GTK
application) and the live session's settings into one tree, and
`build.py` lays that tree into the seed's `/etc` and `/var` and adds the
live user. None of it is in the image. The element also writes
`cleanup-paths`, the list `cleanup.py` works through on the installed
system's first boot to remove those files, itself included.

The live user is a system account (below 1000) marked `SystemAccount=true`
in AccountsService. GDM then still offers initial setup when the live user
logs out, which is how the account is created while the install runs.

The service (`daemon.py`) decides everything that matters; the application
only shows it.

- **Who may use it.** Root, or a member of `wheel` in the active local
  session. The service keeps running after the install, on a system that
  has real accounts by then, and it can erase disks and holds the recovery
  key.
- **Which disks.** The service lists them (`disks.py`): the whole disks
  that `systemd-repart` can partition, never the install media, never one
  that is read-only or under 10 GB. A disk "contains data" when it has
  partitions or a filesystem; a partition table without partitions is an
  empty disk, as it is for `systemd-repart` and `bootc`. The service checks
  the chosen disk again before erasing, by name, by the kernel's disk
  sequence number, and by serial number and size, so a disk that took over
  the name in the meantime is refused.
  The application asks for confirmation every time and names the disk.
- **Encryption is on by default and can be turned off.** It needs a TPM 2.0:
  without one the switch is off and cannot be turned on, and the service
  refuses an encrypted install before anything is erased. An unencrypted
  install has no recovery key and no TPM unit; the rest is the same.
- **One fixed layout.** The whole disk is erased and gets an ESP and one
  btrfs root. There is no partition editor, no dual boot and no separate
  `/home`.
- **The installer can be opened again.** It starts with the live session,
  and "Try Bluefin" closes it. "Install Bluefin" in the live user's app grid
  opens it again.
- **Two phases.** Preparing the disk (partition, encrypt, unlock) can fail
  without harm: the user is back at the disk list with the reason and can
  try again. Only when the session starts to move does the application hand
  over to account setup. A failure after that point cannot be undone, and
  the message says to restart from the install media.
- **The recovery key** is given out only after the install has finished, is
  never written to the journal, and is forgotten when the user leaves the
  final page. The service keeps the outcome in `/run`, so the key survives a
  crash and restart of the service.
- **A Secure Boot key that cannot be queued** does not fail the install. The
  final page says how to enrol it later.

## Patched tools

| Patch | Why |
|---|---|
| `patches/btrfs-progs/` | `mkfs.btrfs --shrink` keeps the block groups it allocated ahead of need. Removing the empty ones takes about 2.9 GiB out of the ISO. Used by `iso/btrfs-progs.bst` only; the image keeps freedesktop-sdk's build. |

The image `oci/bluefin.bst` produces lacks `/sys`, and its layer archives
lack their end marker, which the composefs importer rejects. `fix-layout.py`
repairs both. Exported and published images have neither problem, and it
leaves those byte for byte, so the manifest digest stays the one the
registry serves.

## Reproducibility

The ESP and the seed filesystem are deterministic for the same input:
`mkfs.fat --invariant`, and `mkfs.btrfs` 7.3 with `SOURCE_DATE_EPOCH` and
`DETERMINISTIC_SEED=1`.

One file still differs between builds: the composefs importer writes the
manifest record's references in hash-map order, which changes on every run.
It has no effect on the installed system. Two ISOs from the same image are
identical except for that object and the metadata that points to it.

## Testing

```bash
just check-publish-workflow                       # unit tests for the build helpers, the installer's disk rules and the CI script
python3 scripts/iso_smoke_boot.py ISO --media usb # boots in QEMU until the desktop is up
```

The boot test gives the guest no network. It passes when the display manager
has started and is still running ten seconds later, fails at once on
emergency mode, and reports units that failed during boot as warnings.

A pull request labelled `build` that changes the ISO build gets ISOs built
from the `:pr-N` images that run pushed (`dakota` and `dakota-nvidia`), in
the `pr-test` job. Each is booted in QEMU, uploaded as `<image>-pr-N.iso`
and linked from the run summary. A system installed from one follows
`:pr-N`. The job is not a required check, and the ISOs are deleted when the
pull request closes. They are public while they exist, like the `:pr-N`
images.

A scrub of the live session's filesystem reports checksum errors on the seed
device. That is a property of scrubbing a seed from its sprout and not damage;
check an ISO's seed offline with `btrfs check --check-data-csum` instead.
