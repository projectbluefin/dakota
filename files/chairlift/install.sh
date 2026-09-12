#!/usr/bin/env bash
# Runs inside bluefin/common.bst after common's files have been installed.
# chairlift-upstream is a pinned Git source, never the writable Brew prefix.
set -euo pipefail
root=${1:?install root required}
assets=chairlift-upstream/data
local_files=dakota-chairlift
brewfile=${root}/usr/share/ublue-os/homebrew/preinstall.d/chairlift.Brewfile

# Require common's upstream handoff API before changing any image files;
# an older common pin must not silently ignore the flag.
if [[ $(bash "${root}/usr/libexec/brew-preinstall" --capabilities) != external-chairlift-v1 ]]; then
    echo 'Common lacks external-chairlift-v1; use a common pin that includes the handoff API.' >&2
    exit 1
fi

# Stop rather than silently overriding a future upstream migration. Common
# has shipped both unqualified and Frostyard-qualified versions of this cask.
mapfile -t old < "$brewfile"
if [[ ${#old[@]} != 2 || ${old[0]} != 'tap "frostyard/tap", trusted: true' ||
      ( ${old[1]} != 'cask "chairlift"' && ${old[1]} != 'cask "frostyard/tap/chairlift"' ) ]]; then
    echo 'ChairLift preinstall changed in common; reconcile the Dakota migration.' >&2
    exit 1
fi
install -Dm644 "${local_files}/chairlift.Brewfile" "$brewfile"
install -Dm755 "${local_files}/dakota-brew-managed" "${root}/usr/libexec/dakota-brew-managed"
# Replace the public entry point so manual brew-preinstall and its existing
# user service both acquire the same lock and run the migration first.
printf '#!/bin/sh\nexec /usr/libexec/dakota-brew-managed preinstall "$@"\n' > "${root}/usr/bin/brew-preinstall"
chmod 755 "${root}/usr/bin/brew-preinstall"
for operation in update upgrade; do
    install -d "${root}/usr/lib/systemd/system/brew-${operation}.service.d"
    printf '[Service]\nExecStart=\nExecStart=/usr/libexec/dakota-brew-managed %s\n' "$operation" \
        > "${root}/usr/lib/systemd/system/brew-${operation}.service.d/dakota-managed.conf"
done

# Only the existing bootc staging capability is provided. Do not install the
# ublue/updex/sysupdate helpers or policies as part of a cask migration.
rm -f "${root}/usr/share/polkit-1/actions/org.frostyard.ChairLift.bootc.policy"
install -Dm644 "${assets}/io.projectbluefin.chairlift.bootc.policy" \
    "${root}/usr/share/polkit-1/actions/io.projectbluefin.chairlift.bootc.policy"
rm -f "${root}/usr/share/applications/org.frostyard.ChairLift.desktop"
install -Dm644 "${assets}/io.projectbluefin.chairlift.desktop" \
    "${root}/usr/share/applications/io.projectbluefin.chairlift.desktop"
sed -i 's|^Exec=chairlift-wrapper$|Exec=/home/linuxbrew/.linuxbrew/bin/chairlift-wrapper|' \
    "${root}/usr/share/applications/io.projectbluefin.chairlift.desktop"
for icon in scalable/apps/io.projectbluefin.chairlift.svg \
    scalable/apps/io.projectbluefin.chairlift-flower.svg symbolic/apps/io.projectbluefin.chairlift-symbolic.svg; do
    install -Dm644 "${assets}/icons/hicolor/${icon}" "${root}/usr/share/icons/hicolor/${icon}"
done
rm -f "${root}/usr/share/icons/hicolor/scalable/apps/org.frostyard.ChairLift.svg" \
    "${root}/usr/share/icons/hicolor/scalable/apps/org.frostyard.ChairLift-flower.svg" \
    "${root}/usr/share/icons/hicolor/symbolic/apps/org.frostyard.ChairLift-symbolic.svg"
# Keep common's existing shared-schema /usr/share/chairlift/config.yml:
# fork-only keys make the old Frostyard binary reject the entire config when
# migration is offline/blocked. /etc/chairlift belongs to the administrator.
# New fork-only groups use the fork's defaults; no extra helpers are installed.
