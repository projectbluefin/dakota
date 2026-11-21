#!/usr/bin/env bash
# Bake Dakota's preinstalled Flatpaks into the image-based installer's medium.
#
# Usage (root): bake-flatpaks.sh IMAGE RAW
#
# The published image stays Flatpak-free. The Flatpaks go into the medium's
# stateful /var instead: the composefs deployment's var (state/os/<os>/var,
# which state/deploy/<digest>/var points at) on the raw image's root
# filesystem, which `bootc install` has just created. bootc never touches
# /var after the first deployment, so an update can neither re-add nor
# overwrite them, and an app the user removes stays removed. OS-Installer's
# block copy carries that /var to the installed disk, so first boot starts
# with them offline.
#
# The set is the image's own /usr/share/flatpak/preinstall.d (Bazaar,
# BudsLink, ...): `flatpak preinstall` installs and records it, so
# flatpak-preinstall.service has nothing left to fetch on the installed
# system's first boot. It runs in IMAGE with that var/lib/flatpak
# bind-mounted, so the image's remotes.d descriptors and flatpak version
# apply. Dakota confines with AppArmor, not SELinux: nothing to relabel.
#
# Environment: DAKOTA_RAW_EVIDENCE (default: raw-evidence beside RAW).
set -euo pipefail

IMAGE="${1:?image ref is required}"
RAW="$(realpath "${2:?raw image path is required}")"
EVIDENCE="${DAKOTA_RAW_EVIDENCE:-$(dirname "${RAW}")/raw-evidence}"

[[ ${EUID} -eq 0 ]] || { echo "run as root (loop devices, mounts)" >&2; exit 1; }
mkdir -p "${EVIDENCE}"
loop="$(losetup --find --show --partscan "${RAW}")"
mnt="$(mktemp -d)"
cleanup() {
    set +e
    mountpoint -q "${mnt}" && umount "${mnt}"
    losetup -d "${loop}"
    rmdir "${mnt}"
}
trap cleanup EXIT
udevadm settle
root=""
for p in "${loop}"p*; do
    [[ "$(blkid -p -s TYPE -o value "$p" || true)" == ext4 ]] && root="$p"
done
[[ -n "${root}" ]] || { echo "no ext4 root on ${RAW}" >&2; exit 1; }
mount "${root}" "${mnt}"
mapfile -t deployments < <(find "${mnt}/state/deploy" -mindepth 1 -maxdepth 1 -type d)
[[ ${#deployments[@]} -eq 1 ]] || { echo "expected one composefs deployment, found ${#deployments[@]}" >&2; exit 1; }
var="${deployments[0]}/var"
if [[ -L "${var}" ]]; then
    link="$(readlink "${var}")"
    if [[ "${link}" == /* ]]; then var="${mnt}${link}"; else var="$(realpath -m "${deployments[0]}/${link}")"; fi
fi
[[ -d "${var}" ]] || { echo "the deployment's var (${var}) is not a directory" >&2; exit 1; }
echo "deployment var: ${var#"${mnt}"/}" | tee "${EVIDENCE}/flatpak-var.txt"
install -d "${var}/lib/flatpak"

start=$(date +%s)
podman run --rm --privileged --network host -v "${var}/lib/flatpak:/var/lib/flatpak" -v "${var}:/stateroot-var" \
    "${IMAGE}" bash -euc '
        # Build-time only: a machine id and a system bus for flatpak, a
        # session bus so OCI remotes do not try to autolaunch one, and
        # /var/tmp for token caches.
        [[ -s /etc/machine-id ]] || systemd-machine-id-setup >/dev/null 2>&1 || dbus-uuidgen >/etc/machine-id
        mkdir -p /run/dbus /var/tmp /tmp/cache && chmod 1777 /var/tmp
        export HOME=/tmp XDG_CACHE_HOME=/tmp/cache
        dbus-daemon --system --fork --nopidfile
        DBUS_SESSION_BUS_ADDRESS="$(dbus-daemon --session --fork --print-address)"
        export DBUS_SESSION_BUS_ADDRESS
        retry() {
            local attempt
            for attempt in 1 2 3 4 5; do
                "$@" && return 0
                [[ ${attempt} -lt 5 ]] || { echo "failed 5 times: $*" >&2; return 1; }
                sleep $(( attempt * 30 ))
            done
        }
        cat /usr/share/flatpak/preinstall.d/*
        retry flatpak preinstall --system --noninteractive -y
        flatpak list --system --app --columns=application | sort >/stateroot-var/.dakota-flatpaks-apps
        flatpak list --system --runtime --columns=ref | sort >/stateroot-var/.dakota-flatpaks-runtimes
    '
seconds=$(( $(date +%s) - start ))
mv "${var}/.dakota-flatpaks-apps" "${EVIDENCE}/flatpak-apps.txt"
mv "${var}/.dakota-flatpaks-runtimes" "${EVIDENCE}/flatpak-runtimes.txt"
bytes=$(du -sxb "${var}/lib/flatpak" | cut -f1)
apps=$(wc -l <"${EVIDENCE}/flatpak-apps.txt")
[[ ${apps} -gt 0 ]] || { echo "the bake installed no apps" >&2; exit 1; }
cat "${EVIDENCE}/flatpak-apps.txt"
printf '{"apps": %s, "runtimes": %s, "bytes": %s, "seconds": %s}\n' "${apps}" \
    "$(wc -l <"${EVIDENCE}/flatpak-runtimes.txt")" "${bytes}" "${seconds}" | tee "${EVIDENCE}/flatpaks.json"
