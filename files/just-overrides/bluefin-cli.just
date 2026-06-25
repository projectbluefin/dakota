# vim: set ft=make :

# Initialize the Bluefin CLI developer container (first-time setup)
[group('System')]
setup-bluefin-cli:
    #!/usr/bin/env bash
    set -euo pipefail
    if machinectl list-images --no-legend | grep -q "^homebrew\b"; then
        echo "bluefin-cli container already installed."
        machinectl status homebrew || true
        exit 0
    fi
    echo "Pulling bluefin-cli container image..."
    systemd-sysupdate --component=bluefin-cli update
    echo "Importing container..."
    importctl import-tar /var/lib/bluefin-cli/homebrew-env.tar.zst homebrew
    if [ ! -d /home/linuxbrew/.linuxbrew ]; then
        mkdir -p /home/linuxbrew
        cp -a /var/lib/machines/homebrew/home/linuxbrew/.linuxbrew /home/linuxbrew/
    fi
    machinectl enable homebrew
    machinectl start homebrew
    echo "bluefin-cli ready. Try: brew install cowsay"

# Update the Bluefin CLI container image (keeps your packages)
[group('System')]
update-bluefin-cli:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking for bluefin-cli container updates..."
    systemd-sysupdate --component=bluefin-cli update
    echo "Restarting container to apply update..."
    machinectl restart homebrew

# Open an interactive shell inside the bluefin-cli container
[group('System')]
bluefin-cli-shell:
    machinectl shell linuxbrew@homebrew /bin/bash

# Show status of the bluefin-cli container
[group('System')]
bluefin-cli-status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Container status ==="
    machinectl status homebrew || echo "Container not running"
    echo ""
    echo "=== Brew packages ==="
    brew list --versions 2>/dev/null | head -20 || echo "No packages installed yet"

# Toggle between nspawn (fast) and VM (isolated) security tier
[group('System')]
bluefin-cli-security:
    #!/usr/bin/env bash
    set -euo pipefail
    NSPAWN_CONF=/etc/systemd/nspawn/homebrew.nspawn
    if grep -q "VirtualizationMode" "$NSPAWN_CONF" 2>/dev/null; then
        echo "Already configured for VM tier. To switch back to nspawn, re-run setup."
        exit 1
    fi
    echo "Security tiers:"
    echo "  1) nspawn (default) — namespace isolation, minimal overhead"
    echo "  2) nspawn hardened  — nspawn + capability drop + syscall filter (default)"
    echo "  3) Cloud Hypervisor — full VM isolation, kata-kernel (opt-in)"
    echo ""
    echo "Current tier is baked into /etc/systemd/nspawn/homebrew.nspawn"
    echo "Tier 3 (VM) requires: ujust setup-bluefin-cli-vm"
