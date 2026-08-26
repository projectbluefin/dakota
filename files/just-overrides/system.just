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

# Toggle the Developer Experience (groups + optional dev flatpaks and fonts)
[group('System')]
toggle-devmode:
    #!/usr/bin/env bash
    set -euo pipefail
    # Dakota bakes the developer stack into every image (podman, distrobox,
    # skopeo, git, flatpak-builder, the brew toolchain, ...) and publishes no
    # -dx variant, so unlike Bluefin there is no image rebase here. Developer
    # mode is group membership plus optional extras, and works the same on a
    # fresh ISO install with no registry-bound bootc image.
    if id -nG "$(id -un)" | grep -qw docker ; then
        gum confirm "Developer mode is on (docker/libvirt/incus/serial groups). Disable it?" || exit 0
        for g in docker incus-admin libvirt dialout ; do
            sudo gpasswd -d "$(id -un)" "$g" 2>/dev/null || true
        done
        echo "Developer groups removed. Log out and back in for this to take effect."
        exit 0
    fi

    gum confirm "Would you like to enable developer mode?" || exit 0
    ujust dx-group
    if gum confirm "Do you want to also install the default development flatpaks?" ; then
        ADD_DEVMODE=1 ujust install-system-flatpaks 0 1
    fi
    if gum confirm "Do you want to install extra monospace fonts?" ; then
        brew bundle install --file=/usr/share/ublue-os/homebrew/fonts.Brewfile
    fi
    echo "Log out and back in (or reboot) to pick up the new group memberships."

# Configure docker,incus-admin,libvirt, container manager, serial permissions
[group('System')]
dx-group:
    #!/usr/bin/pkexec bash
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

    echo "Reboot system and log back in to use docker, libvirt, incus, and serial connections."

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
# For additional applications, use ChairLift (Applications page)
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

# Show or add persistent kernel parameters
[group('System')]
kargs $karg="":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== Current kernel parameters ==="
    tr ' ' '\n' < /proc/cmdline
    echo ""

    KARG={{ quote(karg) }}
    if [[ -z "$KARG" ]]; then
        KARG="$(gum input --placeholder "amdgpu.ppfeaturemask=0xffffffff")"
    fi
    [[ -n "$KARG" ]] || { echo "No kernel parameter entered." >&2; exit 1; }
    [[ "$KARG" != *$'\n'* && "$KARG" != *$'\r'* ]] || {
        echo "Kernel parameter must be a single line." >&2
        exit 1
    }

    echo ""
    echo "Adding persistent kernel parameter: $KARG"
    sudo bootc kargs --append="$KARG"
    echo "Kernel parameter staged. Reboot to apply it."

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
