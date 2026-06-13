# vim: set ft=make :
# These are convenience shortcuts, they should not be specific to a desktop, aimed to be rather generic things for both Aurora and Bluefin

uid := `id -u`
shell := `grep :$(id -u): /etc/passwd | cut -d: -f7`

# Boot into this device's BIOS/UEFI screen
bios:
    #!/usr/bin/bash
    if [ ! -d /sys/firmware/efi ]; then
      echo "Rebooting to legacy BIOS from OS is not supported."
      exit 1
    fi

    if gum confirm "Reboot into BIOS?" ; then
      systemctl reboot --firmware-setup
    fi

# Show BIOS info
bios-info:
    #!/usr/bin/bash
    sudo bash <<'EOF'
    echo "Manufacturer: $(dmidecode -s baseboard-manufacturer)"
    echo "Product Name: $(dmidecode -s baseboard-product-name)"
    echo "Version: $(dmidecode -s bios-version)"
    echo "Release Date: $(dmidecode -s bios-release-date)"
    EOF

clean-system:
    #!/usr/bin/bash
    if gum confirm "Prune all Podman images and volumes?"; then
        podman image prune -af
        podman volume prune -f
    fi

    if command -v docker >/dev/null 2>&1; then
      if gum confirm "Prune all Docker images and volumes?"; then
        docker image prune -af
        docker volume prune -f
      fi
    fi

    flatpak uninstall --unused
    if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        brew autoremove
        brew cleanup
    fi

# Show all messages from this boot
logs-this-boot:
    sudo journalctl --no-hostname -b 0

# Show all messages from last boot
logs-last-boot:
    sudo journalctl --no-hostname -b -1

# Enroll Nvidia driver & KMOD signing key for secure boot - Enter password "universalblue" if prompted
enroll-secure-boot-key:
    #!/usr/bin/bash
    ENROLLMENT_PASSWORD="universalblue"
    sudo bash <<EOF
    mokutil --timeout -1
    echo -e "$ENROLLMENT_PASSWORD\n$ENROLLMENT_PASSWORD" | mokutil --import "/etc/pki/akmods/certs/akmods-ublue.der"
    EOF
    echo 'At next reboot, the mokutil UEFI menu UI will be displayed (*QWERTY* keyboard input and navigation).\nThen, select "Enroll MOK", and input "universalblue" as the password'

# Toggle display of the user-motd in terminal
toggle-user-motd:
    #!/usr/bin/bash
    if [ -e "${HOME}/.config/no-show-user-motd" ] ; then
      if gum confirm "Would you like to enable the MOTD?" ; then
        rm -f "${HOME}/.config/no-show-user-motd"
        gum style --foreground 82 "✓ MOTD will now be shown on login."
        exit 0
      fi
    fi
    if gum confirm "Would you like to disable the MOTD?" ; then
      mkdir -p "${HOME}/.config"
      touch "${HOME}/.config/no-show-user-motd"
      gum style --foreground 245 "MOTD hidden. Run 'ujust toggle-user-motd' to bring it back."
      exit 0
    fi

# Check for local overrides
check-local-overrides:
    #!/usr/bin/bash
    RESET="\x1b[0m"
    if [ "${NO_COLOR}" == 1 ]; then
        BLUE_COLOR=""
        GREEN_COLOR=""
        YELLOW_COLOR=""
    else
        BLUE_COLOR="${BLUE_COLOR:-\x1b[38;5;117m}"
        GREEN_COLOR="${GREEN_COLOR:-\x1b[38;5;85m}"
        YELLOW_COLOR="${YELLOW_COLOR:-\x1b[93m}"
    fi

    diff -qr \
      --suppress-common-lines \
      --color="always" \
      --exclude "passwd*" \
      --exclude "group*" \
      --exclude="subgid*" \
      --exclude="subuid*" \
      --exclude="machine-id" \
      --exclude="adjtime" \
      --exclude="fstab" \
      --exclude="system-connections" \
      --exclude="shadow*" \
      --exclude="gshadow*" \
      --exclude="ssh_host*" \
      --exclude="cmdline" \
      --exclude="crypttab" \
      --exclude="hostname" \
      --exclude="localtime" \
      --exclude="locale*" \
      --exclude="*lock" \
      --exclude=".updated" \
      --exclude="*LOCK" \
      --exclude="vconsole*" \
      --exclude="00-keyboard.conf" \
      --exclude="grub" \
      --exclude="system.control*" \
      --exclude="cdi" \
      --exclude="default.target" \
      /usr/etc /etc 2>/dev/null | sed \
          -e '/Binary\ files\ /d ; /Common subdirectories/d' \
          -e "/Files/ s/^/${BLUE_COLOR}&/g" \
          -e "/Files/ s/\$/&${RESET}/g" \
          -e "/Only in/ s/^/${GREEN_COLOR}&/g" \
          -e "/Only in/ s/\$/&${RESET}/g" \
          -e "s/\:.*/${RESET}${YELLOW_COLOR}&${RESET}/g"

# Deprecated alias for ujust report.
device-info:
    #!/usr/bin/bash
    echo ""
    echo "⚠️  'ujust device-info' has been renamed to 'ujust report'."
    echo "    Running 'ujust report' now..."
    echo ""
    just report

# Open the Dakota issue tracker in your browser.
# Usage: ujust file-issue
file-issue:
    #!/usr/bin/bash
    TEMPLATE=$(gum choose "Bug report" "Feature request" "Help this project")
    case "$TEMPLATE" in
        Bug*)     URL="https://github.com/projectbluefin/dakota/issues/new?template=bug-report.yml" ;;
        Feature*) URL="https://github.com/projectbluefin/dakota/issues/new?template=feature-request.yml" ;;
        Help*)    URL="https://github.com/projectbluefin/dakota/issues/new?template=help-this-project.yml" ;;
    esac
    echo "Opening: $URL"
    xdg-open "$URL" 2>/dev/null || echo "Could not open browser. Visit: $URL"

# Confirm you also experience an issue ("me too" with system context).
# Usage: ujust confirm 531
confirm issue_number:
    #!/usr/bin/bash
    set -euo pipefail

    ISSUE="{{issue_number}}"
    REPO="projectbluefin/dakota"

    echo "📋 Confirming you also experience issue #${ISSUE}..."
    echo ""

    # Collect lightweight system fingerprint
    BOOTC_JSON=$(sudo bootc status --json 2>/dev/null || echo '{}')
    BOOTED_IMAGE=$(echo "$BOOTC_JSON" | jq -r '.status.booted.image.image.image // "unknown"')
    BOOTED_DIGEST=$(echo "$BOOTC_JSON" | jq -r '.status.booted.imageDigest // "unknown"')
    KERNEL_VER=$(uname -r)
    ARCH=$(uname -m)
    FAILED_UNITS=$(systemctl list-units --state=failed --no-legend --plain 2>/dev/null \
                   | awk '{print $1}' | head -10 || echo "")

    if [[ -r /etc/machine-id ]]; then
        HOST_ID=$(printf 'ujust-confirm:%s' "$(cat /etc/machine-id)" | sha256sum | cut -c1-8)
    else
        HOST_ID="unknown"
    fi

    # Build the comment
    COMMENT=$(printf '### ✋ I also experience this issue\n\n')
    COMMENT+=$(printf '| Field | Value |\n|-------|-------|\n')
    COMMENT+=$(printf '| Image | `%s` |\n' "$BOOTED_IMAGE")
    COMMENT+=$(printf '| Digest | `%s` |\n' "$BOOTED_DIGEST")
    COMMENT+=$(printf '| Kernel | `%s` |\n' "$KERNEL_VER")
    COMMENT+=$(printf '| Arch | `%s` |\n' "$ARCH")
    COMMENT+=$(printf '| Device ID | `%s` |\n' "$HOST_ID")
    if [[ -n "$FAILED_UNITS" ]]; then
        COMMENT+=$(printf '\n**Failed units:** ')
        COMMENT+=$(echo "$FAILED_UNITS" | tr '\n' ',' | sed 's/,$//')
        COMMENT+=$(printf '\n')
    fi
    COMMENT+=$(printf '\n_Submitted via `ujust confirm %s`_\n' "$ISSUE")

    # Show user what will be posted
    echo "$COMMENT"
    echo ""

    if ! gum confirm "Post this as a comment on issue #${ISSUE}?"; then
        echo "Cancelled."
        exit 0
    fi

    if gh auth status --active &>/dev/null; then
        gh issue comment "$ISSUE" --repo "$REPO" --body "$COMMENT"
        echo ""
        echo "✅ Confirmation posted on issue #${ISSUE}"
    else
        echo ""
        if command -v wl-copy &>/dev/null; then
            printf '%s' "$COMMENT" | wl-copy
            echo "📋 Copied to clipboard! Paste it as a comment on:"
        else
            echo "📋 Copy the text above and paste it as a comment on:"
        fi
        echo "  https://github.com/${REPO}/issues/${ISSUE}"
        echo ""
        echo "Or authenticate gh first: gh auth login"
    fi

# Verify that a fix works on your hardware after upgrading.
# Usage: ujust verify 531
verify issue_number:
    #!/usr/bin/bash
    set -euo pipefail

    ISSUE="{{issue_number}}"
    REPO="projectbluefin/dakota"

    echo "🔍 Verifying fix for issue #${ISSUE}..."
    echo ""

    # Fetch issue context if gh is available
    ISSUE_TITLE=""
    VERIFY_STEPS=""
    if gh auth status --active &>/dev/null; then
        ISSUE_TITLE=$(gh issue view "$ISSUE" --repo "$REPO" --json title --jq '.title' 2>/dev/null || echo "")
        ISSUE_BODY=$(gh issue view "$ISSUE" --repo "$REPO" --json body --jq '.body' 2>/dev/null || echo "")
        # Extract verify-steps block (between ```verify and ```)
        VERIFY_STEPS=$(echo "$ISSUE_BODY" | sed -n '/^```verify/,/^```/p' | sed '1d;$d' || echo "")
    fi

    if [[ -n "$ISSUE_TITLE" ]]; then
        echo "Issue: #${ISSUE} — ${ISSUE_TITLE}"
        echo ""
    fi

    if [[ -n "$VERIFY_STEPS" ]]; then
        echo "── Verification steps from maintainer ──"
        echo "$VERIFY_STEPS"
        echo "─────────────────────────────────────────"
        echo ""
        echo "Please check the steps above on your system."
        echo ""
    else
        echo "No specific verify-steps found in the issue."
        echo "Check whether the bug you experienced is still present after upgrading."
        echo ""
    fi

    # Ask user for their verdict
    VERDICT=$(gum choose "✅ Fixed — bug is gone" "❌ Still broken" "⚠️ Different behavior" "ℹ️ Cannot confirm (did not have the bug)")

    case "$VERDICT" in
        *Fixed*) RESULT="fixed" ; EMOJI="✅" ;;
        *broken*) RESULT="still-broken" ; EMOJI="❌" ;;
        *Different*) RESULT="different" ; EMOJI="⚠️" ;;
        *) RESULT="cannot-confirm" ; EMOJI="ℹ️" ;;
    esac

    # Collect system context
    BOOTC_JSON=$(sudo bootc status --json 2>/dev/null || echo '{}')
    BOOTED_IMAGE=$(echo "$BOOTC_JSON" | jq -r '.status.booted.image.image.image // "unknown"')
    BOOTED_DIGEST=$(echo "$BOOTC_JSON" | jq -r '.status.booted.imageDigest // "unknown"')
    KERNEL_VER=$(uname -r)
    ARCH=$(uname -m)

    if [[ -r /etc/machine-id ]]; then
        HOST_ID=$(printf 'ujust-verify:%s' "$(cat /etc/machine-id)" | sha256sum | cut -c1-8)
    else
        HOST_ID="unknown"
    fi

    # Optional: collect relevant journal if user wants
    JOURNAL_SNIPPET=""
    if [[ "$RESULT" == "still-broken" || "$RESULT" == "different" ]]; then
        if gum confirm "Include recent journal logs for debugging? (last 50 lines of relevant services)" --default=false; then
            JOURNAL_SNIPPET=$(journalctl --no-pager -b -n 50 --priority=err..emerg 2>/dev/null \
                | sed -E 's|/home/[^/[:space:]]+/|/home/<redacted>/|g' \
                | sed -E 's/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/<ip>/g' || echo "")
        fi
    fi

    # Build the verification comment
    COMMENT=$(printf '### %s Verification: **%s**\n\n' "$EMOJI" "$RESULT")
    COMMENT+=$(printf '| Field | Value |\n|-------|-------|\n')
    COMMENT+=$(printf '| Image | `%s` |\n' "$BOOTED_IMAGE")
    COMMENT+=$(printf '| Digest | `%s` |\n' "$BOOTED_DIGEST")
    COMMENT+=$(printf '| Kernel | `%s` |\n' "$KERNEL_VER")
    COMMENT+=$(printf '| Arch | `%s` |\n' "$ARCH")
    COMMENT+=$(printf '| Device ID | `%s` |\n' "$HOST_ID")
    if [[ -n "$JOURNAL_SNIPPET" ]]; then
        COMMENT+=$(printf '\n<details><summary>Journal (errors, last 50 lines)</summary>\n\n```\n%s\n```\n</details>\n' "$JOURNAL_SNIPPET")
    fi
    COMMENT+=$(printf '\n_Submitted via `ujust verify %s`_\n' "$ISSUE")

    # Show user what will be posted
    echo ""
    echo "$COMMENT"
    echo ""

    if ! gum confirm "Post this verification on issue #${ISSUE}?"; then
        echo "Cancelled. You can paste the text above manually."
        exit 0
    fi

    if gh auth status --active &>/dev/null; then
        gh issue comment "$ISSUE" --repo "$REPO" --body "$COMMENT"
        echo ""
        echo "✅ Verification posted on issue #${ISSUE}"
        echo ""
        echo "Thank you for helping confirm whether this fix works!"
    else
        echo ""
        if command -v wl-copy &>/dev/null; then
            printf '%s' "$COMMENT" | wl-copy
            echo "📋 Copied to clipboard! Paste it as a comment on:"
        else
            echo "📋 Copy the text above and paste it as a comment on:"
        fi
        echo "  https://github.com/${REPO}/issues/${ISSUE}"
        echo ""
        echo "Or authenticate gh first: gh auth login"
    fi

# Start an AI-assisted debug session backed by your live system.
# Installs linux-mcp-server and configures Goose automatically.
# Usage: ujust probe
probe:
    #!/usr/bin/bash
    set -euo pipefail

    echo ""
    gum style \
        --border rounded --border-foreground 99 \
        --padding "1 3" --margin "0 1" \
        --bold --foreground 212 \
        "Bluespeed — AI Debug Session"
    echo ""
    gum style --foreground 245 --margin "0 2" \
        "Your system is the context. Ask about logs, services, network, anything."
    echo ""

    # 1. Check goose is installed
    if ! command -v goose &>/dev/null; then
        gum style --foreground 214 --margin "0 2" \
            "Goose is not installed."
        gum style --foreground 245 --margin "0 4" \
            "Install it first:  ujust bbrew  →  select the 'ai' menu option"
        exit 1
    fi

    # 2. Install linux-mcp-server if missing
    if ! command -v linux-mcp-server &>/dev/null; then
        gum style --foreground 245 --margin "0 2" \
            "Installing linux-mcp-server..."
        brew install ublue-os/tap/linux-mcp-server
    fi

    # 3. Wire linux-tools into Goose config if not already present
    GOOSE_CFG="${HOME}/.config/goose/config.yaml"
    if ! grep -q "linux-tools" "$GOOSE_CFG" 2>/dev/null; then
        gum style --foreground 245 --margin "0 2" \
            "Configuring linux-mcp-server in Goose..."
        goose-mcp-setup
    fi

    # 4. If no provider is configured, tell the user how to set one up
    if ! grep -qE "^GOOSE_PROVIDER:|^GOOSE_MODEL:" "$GOOSE_CFG" 2>/dev/null; then
        echo ""
        gum style --foreground 214 --margin "0 2" \
            "No LLM provider configured."
        gum style --foreground 245 --margin "0 2" \
            "Run  goose configure  to set one up, then re-run ujust probe."
        gum style --foreground 245 --margin "0 2" \
            "See docs.projectbluefin.io/troubleshooting for options."
        exit 1
    fi

    # 5. Launch the session
    echo ""
    gum style --foreground 82 --margin "0 2" \
        "Starting session..."
    echo ""
    goose session

# Measure Idle Power Draw
check-idle-power-draw:
    #!/usr/bin/bash
    if ! command -v powerstat ; then
        echo "Powerstat is not available"
        exit 1
    fi
    sudo powerstat -a -r

# Run a one minute system benchmark
[group('System')]
benchmark:
    #!/usr/bin/env bash
    if ! command -v "stress-ng" ; then
        if gum confirm "Stress does not seem to be on your path, do you wish to install it?" ; then
            set -eu
            brew install stress-ng
            brew link stress-ng
            set +eu
        else
            exit 0
        fi
    fi

    echo "Running a 1 minute benchmark ..."
    trap popd EXIT
    pushd "$(mktemp -d)"
    stress-ng --matrix 0 -t 1m --times
