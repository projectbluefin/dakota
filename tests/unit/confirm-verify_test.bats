#!/usr/bin/env bats
# Unit tests for ujust confirm/verify security hardening.
#
# Tests cover: cancel/abort gates, unauthenticated fallback, system fingerprint
# collection, comment construction, clipboard/URL fallback, and journal redaction.
#
# Issue: dakota#1179 (PR #1136 hardened these recipes with no automated tests)
# Run with: bats tests/unit/confirm-verify_test.bats

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
JUST_FILE="${SCRIPT_DIR}/../../files/just-overrides/default.just"

# Extract shell body of a just recipe (strips leading 4-space indent, substitutes
# {{issue_number}} with the supplied value).
_extract_recipe() {
    local recipe="$1" issue="${2:-1234}"
    if [[ ! "$issue" =~ ^[0-9]+$ ]]; then
        echo "ERROR: issue must be numeric" >&2
        return 1
    fi
    awk -v recipe="${recipe}" '
        /^[a-zA-Z_]/ { in_block = ($0 ~ ("^" recipe "[[:space:]]")); next }
        in_block { sub(/^    /, ""); print }
    ' "${JUST_FILE}" \
    | sed "s/{{issue_number}}/${issue}/g"
}

# ── setup / teardown ─────────────────────────────────────────────────────────

setup() {
    BATS_SANDBOX="${BATS_TMPDIR}/just-overrides.${BATS_TEST_NUMBER}.$$"
    STUB_BIN="${BATS_SANDBOX}/bin"
    LOG_DIR="${BATS_SANDBOX}/logs"
    mkdir -p "${STUB_BIN}" "${LOG_DIR}"

    export GH_LOG="${LOG_DIR}/gh.log"
    export GUM_LOG="${LOG_DIR}/gum.log"
    export SYSTEMCTL_LOG="${LOG_DIR}/systemctl.log"
    export JOURNALCTL_LOG="${LOG_DIR}/journalctl.log"

    # Defaults (override with export BEFORE the test body runs — setup() reads them).
    export GH_AUTH_STATUS="${GH_AUTH_STATUS:-0}"
    export GUM_CONFIRM_STATUS="${GUM_CONFIRM_STATUS:-0}"
    export GUM_CHOOSE_RESULT="${GUM_CHOOSE_RESULT:-✅ Fixed — bug is gone}"
    export BOOTC_JSON_RESPONSE="${BOOTC_JSON_RESPONSE:-{\"status\":{\"booted\":{\"image\":{\"image\":{\"image\":\"ghcr.io/projectbluefin/dakota:stable\"}},\"imageDigest\":\"sha256:testdigest\"}}}}"
    export SYSTEMCTL_FAILED="${SYSTEMCTL_FAILED:-}"
    # WL_COPY_AVAILABLE: set to 1 to install the wl-copy stub.
    export WL_COPY_AVAILABLE="${WL_COPY_AVAILABLE:-0}"

    export PATH="${STUB_BIN}:${PATH}"

    # ── stubs ─────────────────────────────────────────────────────────────

    # sudo: pass-through (drop 'sudo', exec remainder).
    cat > "${STUB_BIN}/sudo" <<'STUB'
#!/usr/bin/bash
shift
"$@"
STUB

    # bootc: emit JSON from env for `status --json`.
    cat > "${STUB_BIN}/bootc" <<'STUB'
#!/usr/bin/bash
if [[ "$*" == *"status --json"* ]]; then
    printf '%s\n' "${BOOTC_JSON_RESPONSE}"
fi
STUB

    # uname: return deterministic values.
    cat > "${STUB_BIN}/uname" <<'STUB'
#!/usr/bin/bash
case "$1" in
    -r) echo "6.14.0-300.test.x86_64" ;;
    -m) echo "x86_64" ;;
    *)  /usr/bin/uname "$@" ;;
esac
STUB

    # systemctl: optionally emit failed unit names.
    cat > "${STUB_BIN}/systemctl" <<'STUB'
#!/usr/bin/bash
printf '%s\n' "$*" >> "${SYSTEMCTL_LOG}"
if [[ -n "${SYSTEMCTL_FAILED:-}" ]]; then
    printf '%s\n' "${SYSTEMCTL_FAILED}"
fi
exit 0
STUB

    # gum: default — confirm accepts, choose returns GUM_CHOOSE_RESULT.
    cat > "${STUB_BIN}/gum" <<'STUB'
#!/usr/bin/bash
printf 'gum %s\n' "$*" >> "${GUM_LOG}"
case "$1" in
    confirm) exit "${GUM_CONFIRM_STATUS:-0}" ;;
    choose)  printf '%s\n' "${GUM_CHOOSE_RESULT:-✅ Fixed — bug is gone}"; exit 0 ;;
    *)       exit 0 ;;
esac
STUB

    # gh: log calls; honour GH_AUTH_STATUS; return stub data for issue view.
    cat > "${STUB_BIN}/gh" <<'STUB'
#!/usr/bin/bash
printf '%s\n' "$1 $2 $3" >> "${GH_LOG}"
case "$1 $2" in
    "auth status")
        exit "${GH_AUTH_STATUS:-0}"
        ;;
    "issue view")
        printf '%s\n' "${GH_ISSUE_VIEW_JSON:-{\"title\":\"Stub issue\",\"body\":\"No steps\"}}"
        exit 0
        ;;
    "issue comment")
        exit 0
        ;;
esac
exit 0
STUB

    # wl-copy: installed only when WL_COPY_AVAILABLE=1.
    if [[ "${WL_COPY_AVAILABLE}" == "1" ]]; then
        cat > "${STUB_BIN}/wl-copy" <<'STUB'
#!/usr/bin/bash
printf 'wl-copy called\n' >> "${GH_LOG}"
exit 0
STUB
        chmod +x "${STUB_BIN}/wl-copy"
    fi

    # journalctl: return canned entries with raw IP and home path for redaction tests.
    cat > "${STUB_BIN}/journalctl" <<'STUB'
#!/usr/bin/bash
printf '%s\n' "$*" >> "${JOURNALCTL_LOG}"
printf 'Aug 07 12:00:00 host sshd[1]: Connection from 192.168.1.1\n'
printf 'Aug 07 12:01:00 host sshd[2]: Error in /home/testuser/app\n'
exit 0
STUB

    chmod +x "${STUB_BIN}/sudo" "${STUB_BIN}/bootc" "${STUB_BIN}/uname" \
             "${STUB_BIN}/systemctl" "${STUB_BIN}/gum" "${STUB_BIN}/gh" \
             "${STUB_BIN}/journalctl"

    # Build the scripts under test.
    CONFIRM_SCRIPT="${BATS_SANDBOX}/confirm.sh"
    VERIFY_SCRIPT="${BATS_SANDBOX}/verify.sh"
    _extract_recipe confirm 1234 > "${CONFIRM_SCRIPT}"
    _extract_recipe verify  1234 > "${VERIFY_SCRIPT}"
    chmod +x "${CONFIRM_SCRIPT}" "${VERIFY_SCRIPT}"
}

teardown() {
    rm -rf "${BATS_SANDBOX}"
}

# ── confirm tests ─────────────────────────────────────────────────────────────

@test "confirm: posts gh issue comment when user confirms and gh is authenticated" {
    run bash "${CONFIRM_SCRIPT}"

    [ "$status" -eq 0 ]
    grep -q "issue comment 1234" "${GH_LOG}"
}

@test "confirm: exits 0 with 'Cancelled.' and no gh comment when user declines" {
    GUM_CONFIRM_STATUS=1 run bash "${CONFIRM_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Cancelled."* ]]
    ! grep -q "issue comment" "${GH_LOG}" 2>/dev/null
}

@test "confirm: comment body contains image, digest, kernel, and arch fields" {
    run bash "${CONFIRM_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"ghcr.io/projectbluefin/dakota:stable"* ]]
    [[ "$output" == *"sha256:testdigest"* ]]
    [[ "$output" == *"6.14.0-300.test.x86_64"* ]]
    [[ "$output" == *"x86_64"* ]]
}

@test "confirm: comment body contains Device ID field" {
    run bash "${CONFIRM_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Device ID"* ]]
}

@test "confirm: footer contains ujust confirm invocation line" {
    run bash "${CONFIRM_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"ujust confirm 1234"* ]]
}

@test "confirm: bootc failure falls back to unknown values and still posts" {
    BOOTC_JSON_RESPONSE='{}' run bash "${CONFIRM_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"unknown"* ]]
    # Device ID field still present even with empty bootc JSON.
    [[ "$output" == *"Device ID"* ]]
    grep -q "issue comment 1234" "${GH_LOG}"
}

@test "confirm: failed units appear in comment when systemctl reports them" {
    SYSTEMCTL_FAILED="snapd.service" run bash "${CONFIRM_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"snapd.service"* ]]
}

@test "confirm: no Failed units section when systemctl returns nothing" {
    SYSTEMCTL_FAILED="" run bash "${CONFIRM_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" != *"Failed units"* ]]
}

@test "confirm: unauthenticated without wl-copy prints GitHub URL and no gh comment" {
    GH_AUTH_STATUS=1 run bash "${CONFIRM_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"github.com/projectbluefin/dakota/issues/1234"* ]]
    ! grep -q "issue comment" "${GH_LOG}" 2>/dev/null
}

@test "confirm: unauthenticated with wl-copy prints clipboard message and no gh comment" {
    GH_AUTH_STATUS=1 WL_COPY_AVAILABLE=1 run bash "${CONFIRM_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"clipboard"* ]]
    ! grep -q "issue comment" "${GH_LOG}" 2>/dev/null
}

# ── tests verify ────────────────────────────

@test "verify: posts gh issue comment when user confirms and gh is authenticated" {
    run bash "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]
    grep -q "issue comment 1234" "${GH_LOG}"
}

@test "verify: exits 0 with 'Cancelled.' and no gh comment when user declines posting" {
    # Override gum so that choose returns a verdict but confirm (posting) declines.
    cat > "${STUB_BIN}/gum" <<'STUB'
#!/usr/bin/bash
printf 'gum %s\n' "$*" >> "${GUM_LOG}"
case "$1" in
    choose)  printf '✅ Fixed — bug is gone\n'; exit 0 ;;
    confirm) exit 1 ;;
    *)       exit 0 ;;
esac
STUB
    chmod +x "${STUB_BIN}/gum"

    run bash "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Cancelled."* ]]
    ! grep -q "issue comment" "${GH_LOG}" 2>/dev/null
}

@test "verify: comment contains 'fixed' result and emoji for Fixed verdict" {
    GUM_CHOOSE_RESULT="✅ Fixed — bug is gone" run bash "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"fixed"* ]]
}

@test "verify: comment contains 'still-broken' result for Still broken verdict" {
    # Override gum to confirm always (both journal prompt and post prompt).
    cat > "${STUB_BIN}/gum" <<'STUB'
#!/usr/bin/bash
case "$1" in
    choose)  printf '❌ Still broken\n'; exit 0 ;;
    confirm) exit 0 ;;
    *)       exit 0 ;;
esac
STUB
    chmod +x "${STUB_BIN}/gum"

    run bash "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"still-broken"* ]]
}

@test "verify: comment contains 'different' result for Different behavior verdict" {
    cat > "${STUB_BIN}/gum" <<'STUB'
#!/usr/bin/bash
case "$1" in
    choose)  printf '⚠️ Different behavior\n'; exit 0 ;;
    confirm) exit 0 ;;
    *)       exit 0 ;;
esac
STUB
    chmod +x "${STUB_BIN}/gum"

    run bash "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"different"* ]]
}

@test "verify: comment contains 'cannot-confirm' result for Cannot confirm verdict" {
    GUM_CHOOSE_RESULT="ℹ️ Cannot confirm (did not have the bug)" run bash "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"cannot-confirm"* ]]
}

@test "verify: shows maintainer verify steps when issue body contains a verify block" {
    GH_ISSUE_VIEW_JSON='{"title":"Bug report","body":"Steps:\n```verify\nStep A\nStep B\n```"}' \
        run bash "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]
    # Header and step content must both be present.
    [[ "$output" == *"Verification steps from maintainer"* ]]
    [[ "$output" == *"Step A"* ]]
    # Fallback message must be absent.
    [[ "$output" != *"No specific verify-steps found"* ]]
}

@test "verify: shows generic message and no step block when issue body lacks verify block" {
    GH_ISSUE_VIEW_JSON='{"title":"No steps","body":"Just a description."}' \
        run bash "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No specific verify-steps found"* ]]
    [[ "$output" != *"Verification steps from maintainer"* ]]
}

@test "verify: footer contains ujust verify invocation line" {
    run bash "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"ujust verify 1234"* ]]
}

@test "verify: still-broken verdict with journal consent calls journalctl" {
    cat > "${STUB_BIN}/gum" <<'STUB'
#!/usr/bin/bash
case "$1" in
    choose)  printf '❌ Still broken\n'; exit 0 ;;
    confirm) exit 0 ;;
    *)       exit 0 ;;
esac
STUB
    chmod +x "${STUB_BIN}/gum"

    run bash "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]
    [ -s "${JOURNALCTL_LOG}" ]
}

@test "verify: journal output redacts IP addresses and home directory paths" {
    cat > "${STUB_BIN}/gum" <<'STUB'
#!/usr/bin/bash
case "$1" in
    choose)  printf '❌ Still broken\n'; exit 0 ;;
    confirm) exit 0 ;;
    *)       exit 0 ;;
esac
STUB
    chmod +x "${STUB_BIN}/gum"

    run bash "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]
    # Raw values from the journalctl stub must NOT appear in output.
    [[ "$output" != *"192.168.1.1"* ]]
    [[ "$output" != *"/home/testuser/"* ]]
}

@test "verify: unauthenticated without wl-copy prints GitHub URL and no gh comment" {
    GH_AUTH_STATUS=1 run bash "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"github.com/projectbluefin/dakota/issues/1234"* ]]
    ! grep -q "issue comment" "${GH_LOG}" 2>/dev/null
}

@test "verify: comment body contains image, digest, kernel, and arch fields" {
    run bash "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"ghcr.io/projectbluefin/dakota:stable"* ]]
    [[ "$output" == *"sha256:testdigest"* ]]
    [[ "$output" == *"6.14.0-300.test.x86_64"* ]]
    [[ "$output" == *"x86_64"* ]]
}
