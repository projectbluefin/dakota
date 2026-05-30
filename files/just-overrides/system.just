# vim: set ft=make :
# This file should only contain bluefin specific stuff

# Configure Bluefin-CLI Terminal Experience with Brew
[group('System')]
[no-exit-message]
bluefin-cli:
    @ublue-bling
    brew bundle --file=/usr/share/ublue-os/homebrew/cli.Brewfile

# alias for toggle-devmode
[group('System')]
devmode:
    @ujust toggle-devmode

# Toggle between Bluefin and the Developer Experience
[group('System')]
toggle-devmode:
    #!/usr/bin/env bash
    set -e
    IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
    IMAGE_NAME="$(jq -rc '."image-name"' "${IMAGE_INFO_FILE}")"
    IMAGE_REF="$(jq -rc '."image-ref"' "${IMAGE_INFO_FILE}" | sed "s/.*ghcr/ghcr/")"
    CURRENT_IMAGE="${IMAGE_REF}:$(jq -rc '."image-tag"' "${IMAGE_INFO_FILE}")"
    IMAGE_BASE_NAME="$(cut -f1 -d\- <<< "${IMAGE_NAME}")"
    set +e

    if grep -q -E -e "dx$" <<< "${IMAGE_NAME}" ; then
        gum confirm "Would you like to disable developer mode?" || exit 0
        echo "Rebasing to a non developer image"
        NEW_IMAGE="$(sed "s/\-dx//" <<< $CURRENT_IMAGE)"
        pkexec bootc switch --enforce-container-sigpolicy "${NEW_IMAGE}"
        exit 0
    fi

    gum confirm "Would you like to enable developer mode?" || exit 0
    echo "Rebasing to a developer image"
    NEW_IMAGE="$(sed "s/${IMAGE_BASE_NAME}/${IMAGE_BASE_NAME}-dx/" <<< "${CURRENT_IMAGE}")"
    pkexec bootc switch --enforce-container-sigpolicy "${NEW_IMAGE}"
    if gum confirm "Do you want to also install the default development flatpaks?" ; then
        ADD_DEVMODE=1 ujust install-system-flatpaks 0 1
    fi
    if gum confirm "Do you want to install extra monospace fonts?" ; then
        brew bundle install --file=/usr/share/ublue-os/homebrew/fonts.Brewfile
    fi
    echo "Use ujust dx-group to add your user to the correct groups and complete the installation after rebooting into the development image"

# Configure docker,incus-admin,libvirt, container manager, serial permissions
[group('System')]
dx-group:
    #!/usr/bin/pkexec bash

    # Guard: PKEXEC_UID must be set and non-root
    if [[ -z "${PKEXEC_UID}" ]] || [[ "${PKEXEC_UID}" == "0" ]]; then
        echo "ERROR: run this via ujust, not directly as root."
        exit 1
    fi

    append_group() {
        local group_name="$1"
        if ! grep -q "^$group_name:" /etc/group; then
            echo "Appending $group_name to /etc/group"
            grep "^$group_name:" /usr/lib/group | tee -a /etc/group > /dev/null
        fi
    }

    GROUPS_ADD=("docker" "incus-admin" "libvirt" "dialout")

    for GROUP_ADD in "${GROUPS_ADD[@]}" ; do
        append_group $GROUP_ADD
        usermod -aG $GROUP_ADD {{ `id -un` }}
    done

    echo ""
    echo "Groups added: docker, incus-admin, libvirt, dialout."
    echo "A reboot is required for group membership to take effect."
    echo ""
    if gum confirm "Reboot now?"; then
        systemctl reboot
    fi

# Install system flatpaks for rebasers
[group('System')]
install-system-flatpaks $confirm="1" $dx_only="0":
    #!/usr/bin/env bash
    if [[ "$(jq '."image-flavor"' /usr/share/ublue-os/image-info.json)" =~ dx ]] ; then
        ADD_DEVMODE="${ADD_DEVMODE:-1}"
    fi
    if [ "${ADD_DEVMODE:-0}" == "1" ] ; then
        if [ "$confirm" != 0 ] ; then
            gum confirm "Install development flatpaks?" || exit 0
        fi
        brew bundle --file="${TARGET_FLATPAK_FILE:-/usr/share/ublue-os/homebrew/system-dx-flatpaks.Brewfile}"
    fi
    [ "$dx_only" == 1 ] && exit 0
    if [ "$confirm" != 0 ] ; then
        gum confirm "Install system flatpaks?" || exit 0
    fi
    brew bundle --file="${TARGET_FLATPAK_FILE:-/usr/share/ublue-os/homebrew/system-flatpaks.Brewfile}"

# Install default system flatpaks (alias for install-system-flatpaks)
# For additional applications, use: ujust bbrew
[group('System')]
bluefin-apps:
    echo "Installing default system flatpaks..."
    @ujust install-system-flatpaks

alias switch-stream := rebase-helper
alias switch-streams := rebase-helper
alias rollback-helper := rebase-helper

# Rebase assistant
[group('System')]
rebase-helper:
    @/usr/bin/ublue-rollback-helper

# Show current kernel parameters and explain how to add persistent ones
[group('System')]
kargs:
    #!/usr/bin/env bash
    echo "=== Current kernel parameters ==="
    tr ' ' '\n' < /proc/cmdline
    echo ""
    echo "=== Adding persistent kernel parameters ==="
    echo "Dakota uses bootc with composefs — /usr is read-only so you cannot"
    echo "write to /usr/lib/bootc/kargs.d/ at runtime."
    echo ""
    echo "Options:"
    echo "  1. For a one-time test (lost on next upgrade):"
    echo "     Edit the current BLS entry in /boot/loader/entries/ and add"
    echo "     your parameter to the 'options' line, then reboot."
    echo ""
    echo "  2. For persistent kargs across upgrades, create a local image layer"
    echo "     with a file at /usr/lib/bootc/kargs.d/99-custom.toml containing:"
    echo "     [kargs]"
    echo "     append = [\"your.karg=value\"]"

# Mount a drive persistently using a systemd.mount unit
[group('System')]
mount-drive:
    #!/usr/bin/env bash
    set -e
    echo "This creates a systemd .mount unit in /etc/systemd/system/"
    echo "which survives upgrades. GNOME Disks cannot write /etc/fstab on Dakota."
    echo ""

    DEVICE=$(gum input --placeholder "/dev/nvme1n1p1 or UUID=xxxx-xxxx")
    [[ -z "$DEVICE" ]] && echo "No device entered." && exit 1

    MOUNTPOINT=$(gum input --placeholder "/mnt/data")
    [[ -z "$MOUNTPOINT" ]] && echo "No mountpoint entered." && exit 1

    FSTYPE=$(gum choose --header="Filesystem type?" "auto" "ext4" "btrfs" "xfs" "vfat" "ntfs")

    # systemd unit name is derived from mount point (/ → -, leading - dropped)
    UNIT_NAME="$(systemd-escape --path --suffix=mount "$MOUNTPOINT")"

    sudo mkdir -p "$MOUNTPOINT"
    sudo tee "/etc/systemd/system/${UNIT_NAME}" > /dev/null <<EOF
    [Unit]
    Description=Mount $DEVICE at $MOUNTPOINT

    [Mount]
    What=$DEVICE
    Where=$MOUNTPOINT
    Type=$FSTYPE
    Options=defaults

    [Install]
    WantedBy=multi-user.target
    EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now "$UNIT_NAME"
    echo "Mounted $DEVICE at $MOUNTPOINT and enabled on boot."

# Clean up stale bootloader entries left behind after an OS/image rename
# Closes #531
[group('System')]
cleanup-stale-boot-entries:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Scanning for stale bootloader entries..."
    ENTRIES_DIR="/boot/loader/entries"
    if [[ ! -d "$ENTRIES_DIR" ]]; then
        echo "No $ENTRIES_DIR found — nothing to clean."
        exit 0
    fi
    CURRENT_PREFIX=""
    CURRENT_IMAGE=$(sudo bootc status --json 2>/dev/null | jq -r '.status.booted.image.image.image // empty')
    if [[ -n "$CURRENT_IMAGE" ]]; then
        IMAGE_NAME=$(echo "$CURRENT_IMAGE" | sed -E 's|.*/||; s|:.*||; s|@.*||')
        CURRENT_PREFIX="bootc_${IMAGE_NAME}"
    else
        # Fallback to cmdline parsing if bootc status fails
        CURRENT_PREFIX=$(grep -oP 'bootc[^\s]*' /proc/cmdline | head -1 || echo "")
    fi

    if [[ -z "$CURRENT_PREFIX" ]]; then
        echo "Could not determine current bootc prefix."
        exit 1
    fi
    echo "Current image prefix: $CURRENT_PREFIX"
    STALE=()
    while IFS= read -r -d '' entry; do
        basename="$(basename "$entry")"
        if [[ "$basename" != ${CURRENT_PREFIX}* ]]; then
            STALE+=("$entry")
        fi
    done < <(find "$ENTRIES_DIR" -name "bootc_*.conf" -print0 2>/dev/null)
    if [[ ${#STALE[@]} -eq 0 ]]; then
        echo "No stale entries found. All good!"
        exit 0
    fi
    echo ""
    echo "Found ${#STALE[@]} stale bootloader entries:"
    for entry in "${STALE[@]}"; do
        echo "  - $(basename "$entry")"
    done
    echo ""
    echo "These can cause 'Multiple extra entries in /boot' errors."
    if ! gum confirm "Remove these stale entries?"; then
        echo "Cancelled."
        exit 0
    fi
    sudo rm -f "${STALE[@]}"
    echo "Removed ${#STALE[@]} stale entries."
