kind: manual

# Dakota override of shadow-utils' /etc/pam.d/passwd so a password change
# also re-encrypts the oo7 login keyring.
#
# WHY:
# freedesktop-sdk's components/shadow.bst installs the stock shadow-utils
# passwd stack, which reaches pam_unix through `password include system-auth`
# and never calls pam_oo7. `passwd`, and GNOME Settings (which runs
# /usr/bin/passwd), therefore update /etc/shadow but leave the oo7 login
# keyring sealed with the old password, so it stays locked at the next login.
# gdm-password already hooks pam_oo7, and pam_oo7.so implements
# pam_sm_chauthtok, so only the passwd stack is missing it.
#
# WHY SUBSTACK, NOT INCLUDE:
# system-auth's password stack ends with `password sufficient pam_unix.so`.
# Under `include`, that sufficient success terminates the entire passwd
# stack, so a pam_oo7 line after it would never run. `substack` confines the
# early return to system-auth, the same pattern gdm-password uses with
# password-auth. auth and account keep `include` as shipped.
#
# The leading `-` makes the line a no-op if pam_oo7.so is ever absent, and
# `optional` means a keyring failure can never fail the password change.
#
# OVERRIDE MECHANICS:
# Depends on components/shadow.bst so this element stages after the stock
# file and wins the compose overlap; overlap-whitelist silences the expected
# overlap warning. The file lands in /etc, not /usr/etc, matching
# bluefin/fprintd-system-auth.bst.
#
# Exit condition: drop this element once freedesktop-sdk or gnome-build-meta
# ship a passwd stack that calls pam_oo7. Re-check at every fdsdk bump that
# the stock auth and account lines still match shadow-utils' etc/pam.d/passwd.

public:
  bst:
    overlap-whitelist:
    - /etc/pam.d/passwd

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

depends:
- freedesktop-sdk.bst:components/shadow.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm644 /dev/null "%{install-root}%{sysconfdir}/pam.d/passwd"
    cat > "%{install-root}%{sysconfdir}/pam.d/passwd" <<'EOF'
    #%PAM-1.0
    auth        include       system-auth
    account     include       system-auth
    password    substack      system-auth
    -password   optional      pam_oo7.so use_authtok
    EOF
