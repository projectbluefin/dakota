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

# Manage Dakota developer tools (legacy name; never automatically disables them)
[group('System')]
toggle-devmode:
    @/usr/libexec/dakota-devmode menu

# Set up VMM and local libvirt together, or disable activation without removing data
[group('System')]
manage-virtualization:
    @/usr/libexec/dakota-devmode virtualization

# Install Virtual Machine Manager together with its working system libvirt backend
[group('System')]
setup-virtualization:
    @/usr/libexec/dakota-devmode setup

# Explicitly choose installed developer apps to remove, keeping their user data
[group('System')]
uninstall-dev-apps:
    @/usr/libexec/dakota-devmode uninstall

# Add or retry optional tools, including combined VMM/libvirt setup
[group('System')]
install-dev-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Dakota ships Podman, Distrobox, Git, Skopeo, and flatpak-builder in every image."
    echo "This setup offers optional IDEs, development apps, virtualization, and fonts; it does not install Docker."
    echo "No image switch, group changes, or reboot is needed."
    if [[ ! -t 0 || ! -t 1 ]]; then
        echo "Run ujust install-dev-tools in a terminal to choose optional tools." >&2
        exit 1
    fi
    # Keep optional installs independent so one failure does not block the other.
    status=0
    ujust install-dev-ides || status=$?
    ujust install-dev-flatpaks || status=$?
    if gum confirm "Include virtualization (Virtual Machine Manager + system libvirt)?"; then
        ujust setup-virtualization || status=$?
    fi
    ujust install-dev-fonts || status=$?
    if [ "$status" -ne 0 ]; then
        echo "Some optional tools could not be installed; use the retry commands above." >&2
        exit "$status"
    fi
    echo "Optional developer setup finished. Run ujust devmode again to add tools or retry."

# Compatibility entry point: Dakota no longer applies blanket developer groups
[group('System')]
dx-group:
    @echo "Rootless Podman does not require docker group membership."
    @echo "No group memberships were changed; no reboot is needed for this command."

# Choose optional IDEs from Homebrew and GNOME Builder from Flathub
[group('System')]
install-dev-ides:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! -t 0 || ! -t 1 ]]; then
        echo "Run ujust install-dev-ides in a terminal to choose IDEs." >&2
        exit 1
    fi
    echo "Use the arrow keys to navigate and x to select IDEs, then Enter to install."
    echo "Nothing is preselected. Press Escape or submit an empty selection to skip."
    echo "Homebrew options use ublue-os/tap; GNOME Builder uses the existing system Flathub remote."
    echo "JetBrains Toolbox manages IDE installations; it is not itself an IDE."
    options=("Visual Studio Code (Homebrew)" "Visual Studio Code Insiders (Homebrew)"
        "VSCodium (Homebrew)" "Antigravity IDE (Homebrew)")
    # These tap casks currently download x86_64-only builds.
    if [[ "$(uname -m)" == x86_64 ]]; then
        options+=("Zed (Homebrew)" "JetBrains Toolbox (Homebrew)")
    else
        echo "Zed and JetBrains Toolbox are omitted: their tap casks currently target x86_64."
    fi
    options+=("GNOME Builder (Flatpak)")
    if selections=$(gum choose --no-limit --selected="" --header="Choose optional IDEs" "${options[@]}"); then
        [[ -n "$selections" ]] || { echo "IDE installation skipped."; exit 0; }
    else
        choice_status=$?
        case "$choice_status" in
            1|130) echo "IDE installation skipped."; exit 0 ;;
            *) echo "IDE selection failed. Retry with: ujust install-dev-ides" >&2; exit "$choice_status" ;;
        esac
    fi
    failed=()
    while IFS= read -r selection; do
        case "$selection" in
            "Visual Studio Code (Homebrew)") cask=visual-studio-code-linux ;;
            "Visual Studio Code Insiders (Homebrew)") cask=visual-studio-code-linux@insiders ;;
            "VSCodium (Homebrew)") cask=vscodium-linux ;;
            "Antigravity IDE (Homebrew)") cask=antigravity-ide-linux ;;
            "Zed (Homebrew)") cask=zed-linux ;;
            "JetBrains Toolbox (Homebrew)") cask=jetbrains-toolbox-linux ;;
            "GNOME Builder (Flatpak)")
                if flatpak info --system org.gnome.Builder >/dev/null 2>&1 || flatpak info --user org.gnome.Builder >/dev/null 2>&1; then
                    echo "GNOME Builder is already installed; leaving it unchanged."
                elif ! flatpak install --system --assumeyes flathub org.gnome.Builder; then
                    failed+=("$selection")
                fi
                continue
                ;;
            *) echo "Unknown IDE selection: $selection" >&2; failed+=("$selection"); continue ;;
        esac
        if /home/linuxbrew/.linuxbrew/bin/brew list --cask "ublue-os/tap/$cask" >/dev/null 2>&1; then
            echo "$selection is already installed; leaving it unchanged."
        elif ! /home/linuxbrew/.linuxbrew/bin/brew install --cask "ublue-os/tap/$cask"; then
            failed+=("$selection")
        fi
    done <<< "$selections"
    if [[ ${#failed[@]} -ne 0 ]]; then
        printf 'Could not install: %s\n' "${failed[@]}" >&2
        echo "Other selections were still attempted. Retry with: ujust install-dev-ides" >&2
        exit 1
    fi
    echo "Selected IDE setup finished. Existing IDEs and user settings were not removed."

# Install optional development Flatpaks (IDEs and virtualization are chosen separately)
[group('System')]
install-dev-flatpaks:
    @ADD_DEVMODE=1 ujust install-system-flatpaks 1 1

# Install optional accessibility, office, and other fonts through Homebrew
[group('System')]
install-dev-fonts:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Includes OpenDyslexic Nerd Font (different family names from original OpenDyslexic)."
    echo "This does not remove original OpenDyslexic fonts or change application font selections."
    gum confirm "Install optional extra fonts through Homebrew?" || exit 0
    if brew bundle install --file=/usr/share/ublue-os/homebrew/dakota-fonts.Brewfile; then
        echo "Optional fonts installed."
    else
        status=$?
        echo "Optional font installation failed; some fonts may have installed." >&2
        echo "Developer tools are unaffected. Retry with: ujust install-dev-fonts" >&2
        exit "$status"
    fi

# Install system flatpaks for rebasers
[group('System')]
install-system-flatpaks $confirm="1" $dx_only="0":
    #!/usr/bin/env bash
    set -euo pipefail
    case "$confirm:$dx_only" in
        0:0|0:1|1:0|1:1) ;;
        *) echo "confirm and dx_only must be 0 or 1" >&2; exit 2 ;;
    esac
    if [ "${ADD_DEVMODE:-0}" == "1" ] || [ "$dx_only" == 1 ] ; then
        if [ "$confirm" != 0 ] ; then
            gum confirm "Install optional development Flatpaks?" || exit 0
        fi
        if brew bundle --file="${TARGET_FLATPAK_FILE:-/usr/share/ublue-os/homebrew/dakota-dev-flatpaks.Brewfile}"; then
            echo "Optional development Flatpaks installed."
        else
            status=$?
            echo "Optional development Flatpak installation failed; some apps may have installed." >&2
            echo "Developer tools are unaffected. Retry with: ujust install-dev-flatpaks" >&2
            exit "$status"
        fi
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
