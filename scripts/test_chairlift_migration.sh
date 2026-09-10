#!/usr/bin/env bash
# Offline Bash/jq tests; no Brew commands, network, sudo, or host state changes.
# Single-quoted programs deliberately expand in the isolated child shell.
# shellcheck disable=SC2016
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

reset_fixture() {
    FIXTURE=$(mktemp -d "${WORK}/case.XXXXXX")
    MOCK_PREFIX=${FIXTURE}/prefix
    export FIXTURE MOCK_PREFIX
    mkdir -p "${MOCK_PREFIX}/bin" "${MOCK_PREFIX}/var" "${MOCK_PREFIX}/Caskroom" "${MOCK_PREFIX}/Cellar"
    cp "${ROOT}/scripts/fixtures/chairlift-brew" "${MOCK_PREFIX}/bin/brew"
    chmod +x "${MOCK_PREFIX}/bin/brew"
    : > "${FIXTURE}/commands"
    : > "${FIXTURE}/frostyard"
    printf '0.12.2\n' > "${FIXTURE}/target-version"
    printf '%064d\n' 1 > "${FIXTURE}/target-sha"
    printf 'https://github.com/projectbluefin/chairlift/releases/download/v0.12.2/chairlift_0.12.2_linux_amd64.tar.gz\n' > "${FIXTURE}/target-url"
    printf '{"hash":"previous","packages":["jq"],"casks":["chairlift"]}\n' > "${FIXTURE}/state.json"
    printf 'keep administrator config\n' > "${FIXTURE}/config.yml"
    printf 'keep user settings\n' > "${FIXTURE}/settings"
}

receipt() {
    local tap=${1:-frostyard/tap} version=${2:-0.10.1} name=${3:-chairlift}
    mkdir -p "${MOCK_PREFIX}/Caskroom/${name}/.metadata"
    jq -n --arg tap "$tap" --arg version "$version" '{source:{tap:$tap,version:$version}}' \
        > "${MOCK_PREFIX}/Caskroom/${name}/.metadata/INSTALL_RECEIPT.json"
    if [[ "$name" == chairlift ]]; then
        mkdir -p "${MOCK_PREFIX}/Caskroom/chairlift/${version}"
        for binary in chairlift chairlift-wrapper; do
            printf '#!/bin/sh\nexit 0\n' > "${MOCK_PREFIX}/Caskroom/chairlift/${version}/${binary}"
            chmod +x "${MOCK_PREFIX}/Caskroom/chairlift/${version}/${binary}"
            ln -sfn "${MOCK_PREFIX}/Caskroom/chairlift/${version}/${binary}" "${MOCK_PREFIX}/bin/${binary}"
        done
    fi
}

run_migration() {
    local adopt=${1:-false}
    # Source the real functions, overriding only filesystem locations in this
    # isolated process. Production has no environment-based path overrides.
    bash -c '
        source "$1/files/chairlift/dakota-brew-managed"
        PREFIX=$MOCK_PREFIX
        BREW_BIN=$PREFIX/bin/brew
        STATE_FILE=$FIXTURE/state.json
        migrate_chairlift "$2"
    ' -- "$ROOT" "$adopt" > "${FIXTURE}/output" 2>&1
}

has_command() { grep -Fxq -- "$1" "${FIXTURE}/commands"; }
no_command() { ! has_command "$1"; }
phase() { jq -er --arg phase "$1" '.phase == $phase' "${MOCK_PREFIX}/var/dakota-chairlift-migration.json" >/dev/null; }
check() {
    local title=$1
    shift
    if "$@"; then printf 'ok - %s\n' "$title"
    else printf 'FAIL - %s\n' "$title" >&2; printf 'Fixture: %s\n' "$FIXTURE" >&2; exit 1; fi
}

reset_fixture
check 'fresh install removes stale tap' run_migration
check 'fresh install uses validated dedicated installer' has_command 'install --cask --require-sha ublue-os/tap/chairlift'
check 'fresh install untaps Frostyard' test ! -e "${FIXTURE}/frostyard"

reset_fixture
receipt
check 'managed Frostyard migrates' run_migration
check 'replacement receipt is Bluefin' jq -e '.source.tap == "ublue-os/tap"' "${MOCK_PREFIX}/Caskroom/chairlift/.metadata/INSTALL_RECEIPT.json"
check 'complete checkpoint' phase complete
check 'tap removed' test ! -e "${FIXTURE}/frostyard"
check 'untap alone gets developer mode' test "$(< "${FIXTURE}/developer-commands")" = 'untap frostyard/tap'
check 'order is fetch, uninstall, untap, install' bash -c '
    actual=$(grep -E "^(fetch|uninstall|untap|install) " "$1/commands" | cut -d " " -f1)
    [[ "$actual" == $'"'"'fetch\nuninstall\nuntap\ninstall'"'"' ]]
' -- "$FIXTURE"
check 'preinstall state not rewritten by migration' jq -e '.hash == "previous" and .packages == ["jq"] and .casks == ["chairlift"]' "${FIXTURE}/state.json"
check 'admin config unchanged' test "$(< "${FIXTURE}/config.yml")" = 'keep administrator config'
check 'user settings unchanged' test "$(< "${FIXTURE}/settings")" = 'keep user settings'
: > "${FIXTURE}/commands"
check 'repeat run succeeds' run_migration
check 'repeat never uninstalls' no_command 'uninstall --cask ublue-os/tap/chairlift'
check 'repeat never installs' no_command 'install --cask --require-sha ublue-os/tap/chairlift'

reset_fixture
receipt ublue-os/tap 0.12.2
receipt ublue-os/tap 1 wallpapers
check 'already Bluefin removes duplicate Frostyard tap without removing other casks' run_migration
check 'duplicate wallpaper receipt survives' test -f "${MOCK_PREFIX}/Caskroom/wallpapers/.metadata/INSTALL_RECEIPT.json"
check 'already Bluefin not uninstalled' no_command 'uninstall --cask ublue-os/tap/chairlift'

reset_fixture
receipt
rm "${FIXTURE}/state.json"
check 'unmanaged legacy blocks' bash -c '! "$@"' -- bash -c '
    source "$1/files/chairlift/dakota-brew-managed"
    PREFIX=$MOCK_PREFIX BREW_BIN=$MOCK_PREFIX/bin/brew STATE_FILE=$FIXTURE/state.json
    migrate_chairlift
' -- "$ROOT"
check 'unmanaged legacy not uninstalled' no_command 'uninstall --cask frostyard/tap/chairlift'
check 'explicit adoption works' run_migration true

reset_fixture
receipt third-party/tap 9
if run_migration true; then check 'third-party source rejected even with adoption' false; fi
check 'third-party install preserved' test -f "${MOCK_PREFIX}/Caskroom/chairlift/.metadata/INSTALL_RECEIPT.json"

for failure in fetch-fail tap-fail info-fail; do
    reset_fixture
    receipt
    : > "${FIXTURE}/${failure}"
    if run_migration; then check "${failure} fails" false; fi
    check "${failure} preserves old install" no_command 'uninstall --cask frostyard/tap/chairlift'
    check "${failure} leaves tap" test -e "${FIXTURE}/frostyard"
done

for field in target-url target-sha; do
    reset_fixture
    receipt
    printf 'invalid\n' > "${FIXTURE}/${field}"
    if run_migration; then check "invalid ${field} fails closed" false; fi
    check "invalid ${field} preserves old install" no_command 'uninstall --cask frostyard/tap/chairlift'
done

reset_fixture
receipt
: > "${FIXTURE}/install-fail"
if run_migration; then check 'install failure propagates' false; fi
check 'failed install keeps pending checkpoint' phase replacing
rm "${FIXTURE}/install-fail" "${FIXTURE}/state.json"
check 'resume after uninstall works without old OS state' run_migration
check 'resume completes' phase complete

reset_fixture
receipt
: > "${FIXTURE}/uninstall-fail"
if run_migration; then check 'uninstall failure propagates' false; fi
check 'uninstall failure never installs over legacy' no_command 'install --cask --require-sha ublue-os/tap/chairlift'
check 'uninstall failure leaves tap' test -e "${FIXTURE}/frostyard"
rm "${FIXTURE}/uninstall-fail"
check 'retry failed uninstall' run_migration

for failure in wrong-receipt missing-binaries untap-fail untap-noop; do
    reset_fixture
    receipt
    : > "${FIXTURE}/${failure}"
    if run_migration; then check "${failure} fails verification" false; fi
    check "${failure} never stamps complete" phase replacing
done

reset_fixture
receipt
receipt frostyard/tap 1 wallpapers
if run_migration; then check 'other Frostyard cask blocks removal' false; fi
check 'other Frostyard cask stops before uninstalling ChairLift' no_command 'uninstall --cask frostyard/tap/chairlift'
check 'other Frostyard cask not uninstalled' no_command 'uninstall --cask frostyard/tap/wallpapers'

reset_fixture
receipt
mkdir -p "${MOCK_PREFIX}/Cellar/something/1"
printf '{"source":{"tap":"frostyard/tap"}}\n' > "${MOCK_PREFIX}/Cellar/something/1/INSTALL_RECEIPT.json"
if run_migration; then check 'Frostyard formula blocks removal' false; fi
check 'Frostyard formula stops before uninstalling ChairLift' no_command 'uninstall --cask frostyard/tap/chairlift'

reset_fixture
receipt
printf 'broken\n' > "${MOCK_PREFIX}/Caskroom/chairlift/.metadata/INSTALL_RECEIPT.json"
if run_migration; then check 'corrupt receipt fails closed' false; fi
check 'corrupt receipt never treated as absent' no_command 'untap frostyard/tap'

reset_fixture
receipt
printf 'broken\n' > "${FIXTURE}/state.json"
if run_migration; then check 'corrupt managed state requires adoption' false; fi
check 'corrupt state preserves old cask' no_command 'uninstall --cask frostyard/tap/chairlift'

reset_fixture
receipt
printf '{}\n' > "${MOCK_PREFIX}/var/dakota-chairlift-migration.json"
if run_migration; then check 'invalid checkpoint rejected' false; fi
check 'invalid checkpoint preserves old cask' no_command 'uninstall --cask frostyard/tap/chairlift'

reset_fixture
receipt
# Exercise the production wrapper, including the shared prefix lock, with
# only paths redirected. The prefix owner check uses the real non-root UID.
if [[ $EUID != 0 ]]; then
    printf '#!/bin/sh\nprintf "preinstall\\n" >> "$FIXTURE/commands"\n' > "${FIXTURE}/preinstall"
    chmod +x "${FIXTURE}/preinstall"
    check 'wrapper migrates before normal preinstall' bash -c '
        source "$1/files/chairlift/dakota-brew-managed"
        PREFIX=$MOCK_PREFIX BREW_BIN=$MOCK_PREFIX/bin/brew STATE_FILE=$FIXTURE/state.json PREINSTALL=$FIXTURE/preinstall
        main preinstall
    ' -- "$ROOT"
    check 'normal preinstall runs last' test "$(tail -n1 "${FIXTURE}/commands")" = preinstall
    : > "${FIXTURE}/commands"
    : > "${FIXTURE}/frostyard"
    receipt
    check 'upgrade is independent of migration' bash -c '
        source "$1/files/chairlift/dakota-brew-managed"
        PREFIX=$MOCK_PREFIX BREW_BIN=$MOCK_PREFIX/bin/brew STATE_FILE=$FIXTURE/state.json
        main upgrade
    ' -- "$ROOT"
    check 'upgrade runs without migration' test "$(< "${FIXTURE}/commands")" = upgrade
    mkfifo "${FIXTURE}/update-ready" "${FIXTURE}/update-release"
    exec 8<> "${FIXTURE}/update-ready"
    exec 7<> "${FIXTURE}/update-release"
    timeout 10 bash -c '
        source "$1/files/chairlift/dakota-brew-managed"
        PREFIX=$MOCK_PREFIX BREW_BIN=$MOCK_PREFIX/bin/brew
        main update
    ' -- "$ROOT" &
    update_pid=$!
    if ! read -r -t 15 -u 8 ready; then
        wait "$update_pid" || true
        check 'managed update reached mock Brew before timeout' false
    fi
    check 'update acquired lock before running Brew' test "$ready" = ready
    if flock -n "${MOCK_PREFIX}/var/dakota-brew-managed.lock" true; then
        printf 'release\n' >&7
        wait "$update_pid"
        check 'managed update must hold shared prefix lock' false
    fi
    printf 'release\n' >&7
    wait "$update_pid"
    exec 8>&- 7>&-
    check 'managed lock released after job' flock -n "${MOCK_PREFIX}/var/dakota-brew-managed.lock" true
fi

reset_fixture
receipt ublue-os/tap 0.13.0
check 'newer Bluefin install is not downgraded' run_migration
check 'newer cask preserved' no_command 'uninstall --cask ublue-os/tap/chairlift'

reset_fixture
receipt
mkdir -p "${MOCK_PREFIX}/var/homebrew/pinned_casks"
ln -s "${MOCK_PREFIX}/Caskroom/chairlift" "${MOCK_PREFIX}/var/homebrew/pinned_casks/chairlift"
if run_migration true; then check 'pinned cask needs explicit unpin' false; fi
check 'pinned cask not uninstalled' no_command 'uninstall --cask frostyard/tap/chairlift'

# Regression coverage from the adversarial review: exercise each failure as
# a negative assertion, then prove that the intended recovery actually works.
fails_migration() { ! run_migration "${1:-false}"; }
set_candidate() {
    printf '%s\n' "$1" > "${FIXTURE}/target-version"
    printf 'https://github.com/projectbluefin/chairlift/releases/download/v%s/chairlift.tar.gz\n' "$1" > "${FIXTURE}/target-url"
}

reset_fixture
receipt
check 'initial migration for one-time test' run_migration
set_candidate 0.13.0
: > "${FIXTURE}/commands"
: > "${FIXTURE}/info-fail"
check 'completed migration works offline with a newer candidate' run_migration
check 'completion does not query mutable candidate' no_command 'info --json=v2 --cask ublue-os/tap/chairlift'
check 'completion never implements future upgrades' no_command 'uninstall --cask ublue-os/tap/chairlift'
rm -rf "${MOCK_PREFIX}/Caskroom/chairlift"
check 'completed migration respects user removal' run_migration
check 'removed cask not resurrected' no_command 'install --cask --require-sha ublue-os/tap/chairlift'
receipt
check 'completion does not authorize a later manual Frostyard install' fails_migration
check 'later manual Frostyard install preserved' no_command 'uninstall --cask frostyard/tap/chairlift'

reset_fixture
receipt
printf '{"casks":["ublue-os/tap/chairlift"]}\n' > "${FIXTURE}/state.json"
check 'Bluefin managed record cannot authorize Frostyard' fails_migration
check 'mismatched managed record does not uninstall' no_command 'uninstall --cask frostyard/tap/chairlift'

reset_fixture
receipt
: > "${FIXTURE}/fetch-fail"
check 'failed preparation captures initial ownership' fails_migration
check 'authorization persists before generic state rewrite' phase authorized
rm "${FIXTURE}/state.json" "${FIXTURE}/fetch-fail"
receipt frostyard/tap 0.11.0
check 'authorization binds original receipt, not just source tap' fails_migration
check 'changed source version preserved' no_command 'uninstall --cask frostyard/tap/chairlift'
check 'explicit readoption authorizes changed source' run_migration true

reset_fixture
receipt
: > "${FIXTURE}/uninstall-fail"
check 'create interrupted replacement for fingerprint test' fails_migration
rm "${FIXTURE}/uninstall-fail"
printf '\n' >> "${MOCK_PREFIX}/Caskroom/chairlift/.metadata/INSTALL_RECEIPT.json"
: > "${FIXTURE}/commands"
check 'pending state rejects even a same-version changed receipt' fails_migration
check 'changed receipt not removed' no_command 'uninstall --cask frostyard/tap/chairlift'

for change in version sha url; do
    reset_fixture
    receipt
    : > "${FIXTURE}/install-fail"
    check "create pending install for target ${change} test" fails_migration
    rm "${FIXTURE}/install-fail"
    case "$change" in
        version) set_candidate 0.13.0 ;;
        sha) printf '%064d\n' 2 > "${FIXTURE}/target-sha" ;;
        url) printf 'https://github.com/projectbluefin/chairlift/releases/download/v0.12.2/changed.tar.gz\n' > "${FIXTURE}/target-url" ;;
    esac
    : > "${FIXTURE}/commands"
    check "pending target ${change} cannot silently drift" fails_migration
    check "changed ${change} is not installed" no_command 'install --cask --require-sha ublue-os/tap/chairlift'
    check "explicit readoption accepts inspected ${change}" run_migration true
done

reset_fixture
receipt
: > "${FIXTURE}/missing-binaries"
check 'partial target installation fails verification' fails_migration
rm "${FIXTURE}/missing-binaries" "${FIXTURE}/state.json"
check 'partial target installation repairs on ordinary retry' run_migration
check 'partial repair uses native reinstall' has_command 'reinstall --cask --require-sha ublue-os/tap/chairlift'
check 'partial repair completes' phase complete
rm "${MOCK_PREFIX}/bin/chairlift-wrapper"
check 'damage after completion is not silently repaired' fails_migration
check 'explicit adoption repairs damaged completed installation' run_migration true
ln -sfn /usr/bin/true "${MOCK_PREFIX}/bin/chairlift"
check 'unrelated executable cannot satisfy cask health' fails_migration

for operation in fetch uninstall; do
    reset_fixture
    receipt
    : > "${FIXTURE}/change-during-${operation}"
    check "candidate drift during ${operation} rejected" fails_migration
    check "candidate drift during ${operation} never installs changed target" no_command 'install --cask --require-sha ublue-os/tap/chairlift'
    if [[ "$operation" == fetch ]]; then
        check 'drift detected before removing old cask' no_command 'uninstall --cask frostyard/tap/chairlift'
    else
        check 'post-uninstall drift retains recovery checkpoint' phase replacing
    fi
done

for version in latest 0.13.0-rc.1 0.10.1; do
    reset_fixture
    receipt
    set_candidate "$version"
    check "unsupported target ${version} rejected before uninstall" fails_migration
    check "unsupported ${version} leaves old cask" no_command 'uninstall --cask frostyard/tap/chairlift'
done
reset_fixture
receipt
printf 'https://github.com/projectbluefin/chairlift/releases/download/v0.13.0/chairlift.tar.gz\n' > "${FIXTURE}/target-url"
check 'version and URL tag must agree' fails_migration
check 'mismatched tag leaves old cask' no_command 'uninstall --cask frostyard/tap/chairlift'

for provenance in missing corrupt frostyard; do
    reset_fixture
    receipt
    mkdir -p "${MOCK_PREFIX}/Cellar/orphan/1"
    case "$provenance" in
        corrupt) printf 'broken\n' > "${MOCK_PREFIX}/Cellar/orphan/1/INSTALL_RECEIPT.json" ;;
        frostyard) printf '{"source":{"tap":"frostyard/tap"}}\n' > "${MOCK_PREFIX}/Cellar/orphan/1/INSTALL_RECEIPT.json" ;;
    esac
    check "formula with ${provenance} provenance blocks tap removal" fails_migration
    check "${provenance} formula stops before removing ChairLift" no_command 'uninstall --cask frostyard/tap/chairlift'
    check "${provenance} formula payload retained" test -d "${MOCK_PREFIX}/Cellar/orphan/1"
done
reset_fixture
printf 'https://github.com/frostyard/chairlift/releases/download/v0.12.2/chairlift.tar.gz\n' > "${FIXTURE}/target-url"
check 'fresh install rejects stale Frostyard-backed ublue cask' fails_migration
check 'fresh stale candidate never installed' no_command 'install --cask --require-sha ublue-os/tap/chairlift'

# Execute common's opt-in handoff API directly against a mock prefix. This
# fixture is test-only; BST consumes common itself, never this copy or a patch.
common_script=${ROOT}/scripts/fixtures/common-brew-preinstall
check 'common advertises explicit handoff capability' test "$(bash "$common_script" --capabilities)" = external-chairlift-v1
if [[ $EUID != 0 ]]; then
    reset_fixture
    receipt
    mkdir -p "${FIXTURE}/preinstall.d" "${MOCK_PREFIX}/var/homebrew/pinned_casks"
    cp "${ROOT}/files/chairlift/chairlift.Brewfile" "${FIXTURE}/preinstall.d/chairlift.Brewfile"
    printf 'brew "jq"\n' > "${FIXTURE}/preinstall.d/base.Brewfile"
    ln -s "${MOCK_PREFIX}/Caskroom/chairlift" "${MOCK_PREFIX}/var/homebrew/pinned_casks/chairlift"
    sed -e "s|^PREINSTALL_DIR=.*|PREINSTALL_DIR=\"${FIXTURE}/preinstall.d\"|" \
        -e "s|^STATE_FILE=.*|STATE_FILE=\"${FIXTURE}/state.json\"|" \
        -e "s|^BREW_BIN=.*|BREW_BIN=\"${MOCK_PREFIX}/bin/brew\"|" \
        "$common_script" > "${FIXTURE}/preinstall"
    chmod +x "${FIXTURE}/preinstall"
    wrapper() {
        bash -c '
            source "$1/files/chairlift/dakota-brew-managed"
            PREFIX=$MOCK_PREFIX BREW_BIN=$MOCK_PREFIX/bin/brew STATE_FILE=$FIXTURE/state.json PREINSTALL=$FIXTURE/preinstall
            main "$2"
        ' -- "$ROOT" "$1" > "${FIXTURE}/wrapper-output" 2>&1
    }
    if wrapper preinstall; then check 'blocked migration must report failure' false; fi
    check 'unrelated preinstall proceeds despite pinned ChairLift' has_command "bundle --file=${FIXTURE}/preinstall.d/base.Brewfile"
    check 'generic lifecycle never bundles ChairLift' no_command "bundle --file=${FIXTURE}/preinstall.d/chairlift.Brewfile"
    check 'generic lifecycle hands off ChairLift without removal' no_command 'uninstall --cask chairlift'
    check 'generic state now excludes ChairLift' jq -e '.casks == [] and .packages == ["jq"]' "${FIXTURE}/state.json"
    check 'authorization survives generic handoff' phase authorized
    check 'pinned ChairLift cannot block native upgrades' wrapper upgrade
    check 'native upgrade invoked' has_command upgrade
    rm "${MOCK_PREFIX}/var/homebrew/pinned_casks/chairlift"
    check 'migration resumes after generic state drops legacy ownership' wrapper preinstall
    check 'ownership handoff completes' phase complete
fi

# Exercise the actual BST install commands with inert upstream assets and a
# synthetic image root. No modifications to /usr, /etc, or the real prefix.
stage=${WORK}/stage
image=${stage}/image
mkdir -p "${stage}/chairlift-upstream/data/icons/hicolor/"{scalable/apps,symbolic/apps} \
    "${image}/usr/share/ublue-os/homebrew/preinstall.d" "${image}/usr/bin" \
    "${image}/usr/share/applications" "${image}/usr/share/polkit-1/actions" "${image}/etc/chairlift" "${image}/usr/share/chairlift"
cp -r "${ROOT}/files/chairlift" "${stage}/dakota-chairlift"
mkdir -p "${image}/usr/libexec"
# Simulate older common safely: it ignores flags and exits 0 with a message.
# The assembly guard must reject that, not just test the process exit code.
printf '#!/bin/bash\necho "brew-preinstall: brew not found, skipping"\n' > "${image}/usr/libexec/brew-preinstall"
printf 'tap "frostyard/tap", trusted: true\ncask "chairlift"\n' \
    > "${image}/usr/share/ublue-os/homebrew/preinstall.d/chairlift.Brewfile"
printf 'keep my settings\n' > "${image}/etc/chairlift/config.yml"
printf 'shared schema for old and new casks\n' > "${image}/usr/share/chairlift/config.yml"
printf 'legacy\n' > "${image}/usr/share/applications/org.frostyard.ChairLift.desktop"
printf 'legacy\n' > "${image}/usr/share/polkit-1/actions/org.frostyard.ChairLift.bootc.policy"
printf '[Desktop Entry]\nName=ChairLift\nType=Application\nExec=chairlift-wrapper\nIcon=io.projectbluefin.chairlift\n' \
    > "${stage}/chairlift-upstream/data/io.projectbluefin.chairlift.desktop"
printf '<policyconfig/>\n' > "${stage}/chairlift-upstream/data/io.projectbluefin.chairlift.bootc.policy"
for icon in scalable/apps/io.projectbluefin.chairlift.svg scalable/apps/io.projectbluefin.chairlift-flower.svg symbolic/apps/io.projectbluefin.chairlift-symbolic.svg; do
    printf '<svg/>\n' > "${stage}/chairlift-upstream/data/icons/hicolor/${icon}"
done
if (cd "$stage" && bash dakota-chairlift/install.sh "$image") > "${WORK}/old-common-output" 2>&1; then
    check 'older common must fail image assembly' false
fi
check 'old common reports missing capability' grep -Fq 'Common lacks external-chairlift-v1' "${WORK}/old-common-output"
check 'old common fails before replacing image assets' test "$(< "${image}/usr/share/applications/org.frostyard.ChairLift.desktop")" = legacy
cp "$common_script" "${image}/usr/libexec/brew-preinstall"
check 'BST installation script succeeds with upstream handoff API' bash -c 'cd "$1" && bash dakota-chairlift/install.sh "$2"' -- "$stage" "$image"
check 'Brewfile uses qualified Bluefin cask' cmp "${ROOT}/files/chairlift/chairlift.Brewfile" "${image}/usr/share/ublue-os/homebrew/preinstall.d/chairlift.Brewfile"
check 'old policy removed' test ! -e "${image}/usr/share/polkit-1/actions/org.frostyard.ChairLift.bootc.policy"
check 'old desktop removed' test ! -e "${image}/usr/share/applications/org.frostyard.ChairLift.desktop"
check 'root-owned policy comes from pinned source' cmp "${stage}/chairlift-upstream/data/io.projectbluefin.chairlift.bootc.policy" "${image}/usr/share/polkit-1/actions/io.projectbluefin.chairlift.bootc.policy"
check 'no extra privileged policy installed' test "$(find "${image}/usr/share/polkit-1/actions" -type f | wc -l)" -eq 1
check 'image launcher has absolute brew prefix' grep -Fxq 'Exec=/home/linuxbrew/.linuxbrew/bin/chairlift-wrapper' "${image}/usr/share/applications/io.projectbluefin.chairlift.desktop"
check 'administrator config preserved during image assembly' test "$(< "${image}/etc/chairlift/config.yml")" = 'keep my settings'
check 'shared-schema image config preserved' test "$(< "${image}/usr/share/chairlift/config.yml")" = 'shared schema for old and new casks'
check 'public preinstall wrapper invokes migration' grep -Fq '/usr/libexec/dakota-brew-managed preinstall' "${image}/usr/bin/brew-preinstall"
for operation in update upgrade; do
    check "${operation} service shares lock" grep -Fxq "ExecStart=/usr/libexec/dakota-brew-managed ${operation}" "${image}/usr/lib/systemd/system/brew-${operation}.service.d/dakota-managed.conf"
done
check 'uupd routes Brew through same lock' grep -Fq '"path": "/usr/libexec/dakota-brew-managed"' "${ROOT}/elements/bluefin/uupd.bst"
if (cd "$stage" && bash dakota-chairlift/install.sh "$image") > "${WORK}/drift-output" 2>&1; then
    check 'changed upstream Brewfile must fail assembly' false
fi
printf 'tap "frostyard/tap", trusted: true\ncask "frostyard/tap/chairlift"\n' \
    > "${image}/usr/share/ublue-os/homebrew/preinstall.d/chairlift.Brewfile"
check 'assembly accepts current common qualified legacy declaration' bash -c 'cd "$1" && bash dakota-chairlift/install.sh "$2"' -- "$stage" "$image"
printf 'All ChairLift migration tests passed.\n'
