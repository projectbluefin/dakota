#!/usr/bin/env bash
# Build the Dakota raw disk image that is both the live medium and the install
# payload of the experimental image-based installer (shared with Utah:
# projectbluefin/utah docs/adr/0001-image-based-installer.md).
#
# Usage (root): build-raw-image.sh IMAGE OUTPUT_RAW [TARGET_IMGREF]
#
#   1. `bootc install to-disk --composefs-backend --bootloader systemd
#      --filesystem ext4` the image into OUTPUT_RAW: a 2 GiB ESP holding
#      systemd-boot, the Type #1 entry, the kernel and the initramfs, plus an
#      ext4 root (fs-verity on) holding the composefs repository and
#      state/deploy/<digest>. This is what bootc-installer/fisherman does at
#      install time today, done once at build time. The root is ext4, not
#      btrfs: Dakota's 7.3 kernel lacks mainline 254e15591ee4 ("btrfs: fix the
#      fsverity callback where unexpected range is verified", v7.4-rc2), and
#      composefs depends on fs-verity reads being right.
#   2. Add a "Dakota Live" Type #1 entry on the ESP (medium.py live-entry): the
#      deployment's own entry with `ro dakota.live` instead of `rw` and an extra
#      initrd, EFI/Linux/dakota-live/live.initrd, a cpio that carries bootc's
#      setup-root config with a tmpfs overlay over / (with /etc and /var). It is made
#      systemd-boot's default in loader.conf. OS-Installer's install.sh removes
#      the entry, that initrd and the default from the installed copy. The
#      image, its initramfs and the deployment's own entry are untouched.
#
# Environment:
#   DAKOTA_RAW_SIZE           sparse image size (default 24G)
#   DAKOTA_RAW_LIVE_KARGS     extra kargs for the live entry only (CI: dakota.live.debug)
#   DAKOTA_RAW_SSH_PUBKEY     CI only: root authorized key (bootc --root-ssh-authorized-keys)
#   DAKOTA_RAW_DEBUG_SSHD=1   CI only: enable sshd as a local /etc change of the
#                             deployment, so it survives `bootc switch`
#   DAKOTA_RAW_EVIDENCE       directory for partition table, entries and sizes
set -euo pipefail

IMAGE="${1:?image ref is required}"
OUT="${2:?output raw path is required}"
TARGET_IMGREF="${3:-ghcr.io/projectbluefin/dakota:testing}"
SIZE="${DAKOTA_RAW_SIZE:-24G}"
LIVE_KARGS="${DAKOTA_RAW_LIVE_KARGS:-}"
EVIDENCE="${DAKOTA_RAW_EVIDENCE:-$(dirname "${OUT}")/raw-evidence}"
ESP_TYPE=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
LIVE_ENTRY=dakota-live
LIVE_INITRD=/EFI/Linux/dakota-live/live.initrd
# Dakota's own install kargs (Justfile generate-bootable-image): the splash
# gives the graphical, branded Plymouth LUKS prompt on the installed disk.
INSTALL_KARGS=(systemd.firstboot=no splash quiet)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ ${EUID} -eq 0 ]] || { echo "run as root (bootc install, loop devices)" >&2; exit 1; }
mkdir -p "$(dirname "${OUT}")" "${EVIDENCE}"
OUT="$(realpath -m "${OUT}")"
data="$(dirname "${OUT}")"

rm -f "${OUT}"
truncate -s "${SIZE}" "${OUT}"

install_args=(--via-loopback "/data/$(basename "${OUT}")" --filesystem ext4 --wipe
    --composefs-backend --bootloader systemd --generic-image --target-imgref "${TARGET_IMGREF}")
for karg in "${INSTALL_KARGS[@]}"; do install_args+=(--karg "${karg}"); done
if [[ -n "${DAKOTA_RAW_SSH_PUBKEY:-}" ]]; then
    install -m 0644 "${DAKOTA_RAW_SSH_PUBKEY}" "${data}/root-key.pub"
    install_args+=(--root-ssh-authorized-keys /data/root-key.pub)
fi
echo "bootc install to-disk ${IMAGE} -> ${OUT} (${SIZE}, target ${TARGET_IMGREF})"
start=$(date +%s)
podman run --rm --privileged --pid=host \
    -v /dev:/dev -v /var/lib/containers:/var/lib/containers -v "${data}:/data" \
    --security-opt label=type:unconfined_t \
    "${IMAGE}" bootc install to-disk "${install_args[@]}"
install_seconds=$(( $(date +%s) - start ))
echo "bootc install to-disk took ${install_seconds}s" | tee "${EVIDENCE}/install-time.txt"
rm -f "${data}/root-key.pub"

loop="$(losetup --find --show --partscan "${OUT}")"
mnt="$(mktemp -d)"
cleanup() {
    set +e
    for m in "${mnt}"/*; do mountpoint -q "$m" && umount "$m"; done
    losetup -d "${loop}"
    rm -rf "${mnt}"
}
trap cleanup EXIT
udevadm settle
sfdisk --dump "${loop}" | tee "${EVIDENCE}/partitions.txt"
blkid "${loop}"p* | tee "${EVIDENCE}/blkid.txt"

esp="" root=""
for p in "${loop}"p*; do
    ptype="$(blkid -p -s PART_ENTRY_TYPE -o value "$p" | tr '[:upper:]' '[:lower:]')"
    fstype="$(blkid -p -s TYPE -o value "$p" || true)"
    if [[ "${ptype}" == "${ESP_TYPE}" ]]; then esp="$p"
    elif [[ "${fstype}" == ext4 ]]; then root="$p"
    fi
done
[[ -n "${esp}" && -n "${root}" ]] || { echo "unexpected layout: esp=${esp} root=${root}" >&2; exit 1; }
dumpe2fs -h "${root}" 2>/dev/null | grep -E '^(Filesystem features|Filesystem volume name|Filesystem UUID)' \
    | tee "${EVIDENCE}/root-ext4.txt"
grep -qw verity "${EVIDENCE}/root-ext4.txt" || { echo "the ext4 root has no verity feature" >&2; exit 1; }
mkdir -p "${mnt}/efi" "${mnt}/root"
mount "${root}" "${mnt}/root"
mount "${esp}" "${mnt}/efi"
entries_dir="${mnt}/efi/loader/entries"

# --- Live entry ---------------------------------------------------------------
mapfile -t entries < <(find "${entries_dir}" -name '*.conf' ! -name "${LIVE_ENTRY}.conf")
[[ ${#entries[@]} -eq 1 ]] || { echo "expected one deployment entry on the ESP, found ${#entries[@]}" >&2; exit 1; }
cpio_root="$(mktemp -d)"
install -D -m 0644 "${HERE}/live/setup-root-conf.toml" "${cpio_root}/usr/lib/composefs/setup-root-conf.toml"
install -d "$(dirname "${mnt}/efi${LIVE_INITRD}")"
(cd "${cpio_root}" && find . -mindepth 1 | LC_ALL=C sort | cpio --quiet -o -H newc -R 0:0 --reproducible) \
    >"${mnt}/efi${LIVE_INITRD}"
rm -rf "${cpio_root}"
python3 "${HERE}/medium.py" live-entry "${entries[0]}" "${entries_dir}/${LIVE_ENTRY}.conf" "${LIVE_INITRD}" "${LIVE_KARGS}"
python3 "${HERE}/medium.py" loader-conf "${mnt}/efi/loader/loader.conf" "${LIVE_ENTRY}"
cat "${entries[0]}" >"${EVIDENCE}/entry-installed.conf"
tee "${EVIDENCE}/entry-live.conf" <"${entries_dir}/${LIVE_ENTRY}.conf"
tee "${EVIDENCE}/loader.conf" <"${mnt}/efi/loader/loader.conf"
find "${mnt}/efi" -type f -printf '%s %P\n' | sort -k2 | tee "${EVIDENCE}/esp-files.txt"

# --- Deployment facts and CI-only diagnostics ----------------------------------
mapfile -t deployments < <(find "${mnt}/root/state/deploy" -mindepth 1 -maxdepth 1 -type d)
[[ ${#deployments[@]} -eq 1 ]] || { echo "expected one composefs deployment, found ${#deployments[@]}" >&2; exit 1; }
d="${deployments[0]}"
{
    echo "deployment: ${d#"${mnt}/root/"}"
    echo "machine-id: '$(cat "$d/etc/machine-id" 2>/dev/null)'"
    echo "== fstab"; cat "$d/etc/fstab" 2>/dev/null || echo "(none)"
    echo "== origin"; cat "${d}.origin" "$d"/*.origin 2>/dev/null || true
    echo "== root"; ls -la "${mnt}/root" "${mnt}/root/state" "${mnt}/root/state"/* 2>&1
} | tee "${EVIDENCE}/deployment.txt"
if [[ "${DAKOTA_RAW_DEBUG_SSHD:-0}" == 1 ]]; then
    podman run --rm --entrypoint test "${IMAGE}" -e /usr/lib/systemd/system/sshd.service \
        || { echo "DAKOTA_RAW_DEBUG_SSHD=1 but the image has no sshd.service" >&2; exit 1; }
    install -d "$d/etc/systemd/system/multi-user.target.wants"
    ln -sfn /usr/lib/systemd/system/sshd.service "$d/etc/systemd/system/multi-user.target.wants/sshd.service"
    echo "CI: sshd.service enabled in the deployment's /etc" | tee -a "${EVIDENCE}/deployment.txt"
fi
sync
umount "${mnt}/efi"
umount "${mnt}/root"

{
    echo "apparent: $(du -h --apparent-size "${OUT}" | cut -f1)"
    echo "allocated: $(du -h "${OUT}" | cut -f1)"
} | tee "${EVIDENCE}/size.txt"
printf '{"raw_apparent_bytes": %s, "raw_allocated_bytes": %s, "bootc_install_seconds": %s}\n' \
    "$(du -b --apparent-size "${OUT}" | cut -f1)" "$(( $(du -k "${OUT}" | cut -f1) * 1024 ))" \
    "${install_seconds}" | tee "${EVIDENCE}/medium.json"
echo "Raw image ready: ${OUT}"
