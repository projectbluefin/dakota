#!/usr/bin/env bash
# Shrink Dakota's image-based installer medium to its content.
#
# Usage (root): shrink-raw-image.sh IMAGE RAW
#
# bootc installs into a sparse file sized for headroom (DAKOTA_RAW_SIZE). The
# medium only has to hold what is on it: the live session writes to tmpfs
# overlays, and OS-Installer's install.sh grows the root on the target
# (systemd-repart gives root the rest of the disk, then resize2fs). So:
#
#   1. record what takes the space (size-breakdown.txt);
#   2. fstrim the ESP and the root, which punches holes in the file for free
#      blocks;
#   3. shrink the ext4 root to its minimum (resize2fs -M) plus
#      DAKOTA_RAW_SHRINK_MARGIN_MIB (default 256);
#   4. cut the root partition and the file right after it (medium.py
#      shrink-plan), then write the partition table again for the new size
#      (medium.py shrunk-dump): a truncated file has no backup GPT.
#
# e2fsprogs runs from IMAGE, so the tools match the installed system.
#
# Environment: DAKOTA_RAW_EVIDENCE (default: raw-evidence beside RAW).
set -euo pipefail

IMAGE="${1:?image ref is required}"
RAW="$(realpath "${2:?raw image path is required}")"
EVIDENCE="${DAKOTA_RAW_EVIDENCE:-$(dirname "${RAW}")/raw-evidence}"
MARGIN_MIB="${DAKOTA_RAW_SHRINK_MARGIN_MIB:-256}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ ${EUID} -eq 0 ]] || { echo "run as root (loop devices, mounts)" >&2; exit 1; }
mkdir -p "${EVIDENCE}"
before_apparent=$(du -b --apparent-size "${RAW}" | cut -f1)
before_allocated=$(( $(du -k "${RAW}" | cut -f1) * 1024 ))

loop="$(losetup --find --show --partscan "${RAW}")"
trap 'losetup -d "${loop}" 2>/dev/null || true' EXIT
udevadm settle
sfdisk --json "${loop}" >"${EVIDENCE}/partitions-before-shrink.json"
root="$(python3 - "${EVIDENCE}/partitions-before-shrink.json" <<'PY'
import json, sys
parts = json.load(open(sys.argv[1]))["partitiontable"]["partitions"]
print(max(parts, key=lambda p: int(p["start"]))["node"])
PY
)"

# Prints the root filesystem's size on its device, in bytes, after shrinking.
fs_bytes="$(podman run --rm --privileged -v /dev:/dev -e LOOP="${loop}" -e ROOT="${root}" \
    -e MARGIN="$(( MARGIN_MIB * 1024 * 1024 ))" "${IMAGE}" bash -euc '
        report() { echo "$@" >&2; }
        [[ "$(blkid -p -s TYPE -o value "${ROOT}")" == ext4 ]] || { report "root ${ROOT} is not ext4"; exit 1; }
        mkdir -p /m /p
        mount "${ROOT}" /m
        {
            echo "== used per top-level directory of the root filesystem (du -sx, MiB)"
            du -sxm /m/* /m/state/* /m/state/os/*/var/* /m/state/os/*/var/lib/* 2>/dev/null | sort -rn | head -40
            df -B1 --output=used,size /m | tail -1
            for p in "${LOOP}"p*; do
                [[ "${p}" == "${ROOT}" ]] && continue
                [[ "$(blkid -p -s TYPE -o value "${p}" || true)" == vfat ]] || continue
                mount "${p}" /p
                echo "== ESP ${p} used"; df -B1 --output=used,size /p | tail -1
                du -sxm /p/* /p/EFI/* /p/EFI/Linux/* 2>/dev/null | sort -rn | head -12
                fstrim -v /p
                umount /p
            done
            fstrim -v /m
        } >&2
        umount /m
        e2fsck -fy "${ROOT}" >&2 || [[ $? -le 1 ]]
        resize2fs -M "${ROOT}" >&2
        bs=$(dumpe2fs -h "${ROOT}" 2>/dev/null | awk -F: "/^Block size/ {gsub(/ /, \"\", \$2); print \$2}")
        blocks=$(dumpe2fs -h "${ROOT}" 2>/dev/null | awk -F: "/^Block count/ {gsub(/ /, \"\", \$2); print \$2}")
        target=$(( (blocks * bs + MARGIN + 1048575) / 1048576 * 1048576 ))
        resize2fs "${ROOT}" "$(( target / 1024 ))K" >&2
        report "ext4 minimum $(( blocks * bs )) bytes; resized to ${target} with the margin"
        echo "${target}"
    ' 2>"${EVIDENCE}/size-breakdown.txt")"
cat "${EVIDENCE}/size-breakdown.txt"
[[ "${fs_bytes}" =~ ^[0-9]+$ ]] || { echo "could not read the shrunk filesystem size: '${fs_bytes}'" >&2; exit 1; }
losetup -d "${loop}"
trap - EXIT

read -r partno sectors image_bytes < <(python3 "${HERE}/medium.py" shrink-plan \
    "${EVIDENCE}/partitions-before-shrink.json" "${fs_bytes}")
echo "root filesystem ${fs_bytes} bytes: partition ${partno} -> ${sectors} sectors, image -> ${image_bytes} bytes"
sfdisk --dump "${RAW}" >"${EVIDENCE}/partitions-before-shrink.dump"
python3 "${HERE}/medium.py" shrunk-dump "${EVIDENCE}/partitions-before-shrink.dump" "${partno}" "${sectors}" \
    >"${EVIDENCE}/partitions-shrunk.dump"
truncate -s "${image_bytes}" "${RAW}"
sfdisk --quiet --no-reread --wipe never --wipe-partitions never "${RAW}" <"${EVIDENCE}/partitions-shrunk.dump"
sfdisk --verify "${RAW}"
sfdisk --dump "${RAW}" | tee "${EVIDENCE}/partitions.txt"
grep -qx 'label: gpt' "${EVIDENCE}/partitions.txt" || { echo "the shrunk medium lost its GPT" >&2; exit 1; }

after_apparent=$(du -b --apparent-size "${RAW}" | cut -f1)
after_allocated=$(( $(du -k "${RAW}" | cut -f1) * 1024 ))
printf '{"before_apparent_bytes": %s, "before_allocated_bytes": %s, "apparent_bytes": %s, "allocated_bytes": %s, "root_fs_bytes": %s}\n' \
    "${before_apparent}" "${before_allocated}" "${after_apparent}" "${after_allocated}" "${fs_bytes}" \
    | tee "${EVIDENCE}/shrink.json"
