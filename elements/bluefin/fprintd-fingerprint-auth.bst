kind: manual

# Dakota override of freedesktop-sdk's /etc/pam.d/fingerprint-auth (issue #674).
#
# WHAT THIS FIXES:
# fdsdk 26.08 ships `auth sufficient pam_fprintd.so` followed by
# `auth required pam_deny.so`. When a reader is present but the user has no
# enrolled prints, pam_fprintd returns PAM_AUTHINFO_UNAVAIL. `sufficient`
# ignores that result, pam_deny then turns the stack into PAM_AUTH_ERR, and GDM
# reports a generic "fingerprint authentication didn't work" failure instead of
# ServiceUnavailable. GNOME Shell only suppresses retries for unavailable
# services, so it restarts gdm-fingerprint every few seconds and the error
# interrupts password entry at the greeter and lock screen.
#
# THE FIX:
# Replace `sufficient` with an explicit control field that terminates the
# stack on PAM_AUTHINFO_UNAVAIL so GDM sees the real result and marks the
# fingerprint service unavailable for that conversation. This is byte-identical
# to fdsdk master after freedesktop-sdk!34283 (commit ef25f79), which fixes
# GNOME/gnome-build-meta#734. A no-match still falls through to pam_deny and is
# rejected as before.
#
# KNOWN TRADEOFF:
# pam_fprintd's verification timeout (30s default) is also reported as
# PAM_AUTHINFO_UNAVAIL. An enrolled user idling at the prompt past the timeout
# gets a silent stop instead of a restart loop; the reader resumes when the
# auth prompt is recreated. Upstream accepted this. `timeout=` on the
# pam_fprintd line is the knob if it ever needs tuning.
#
# OVERRIDE MECHANICS:
# Same pattern as fprintd-system-auth.bst: fdsdk's components/linux-pam.bst
# installs the stock file from files/linux-pam-config to /etc/pam.d, this
# element depends on it so it stages after the stock file and wins the compose
# overlap, and overlap-whitelist silences the expected warning. The file is
# not patched through the junction because it is a source of linux-pam.bst
# and changing it would cascade a rebuild of the whole runtime.
#
# Exit condition: drop this element when the freedesktop-sdk.bst junction ref
# contains ef25f79 (fdsdk master, or release/26.08 if it gets backported). At
# every fdsdk bump, diff the file below against files/linux-pam-config/
# fingerprint-auth in the new ref and re-sync anything other than the
# pam_fprintd control field.

public:
  bst:
    overlap-whitelist:
    - /etc/pam.d/fingerprint-auth

# No external sources — the file is inline.
build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

# Stage after the stock file so this override wins the overlap deterministically.
depends:
- freedesktop-sdk.bst:components/linux-pam.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm644 /dev/null "%{install-root}%{sysconfdir}/pam.d/fingerprint-auth"
    cat > "%{install-root}%{sysconfdir}/pam.d/fingerprint-auth" <<'EOF'
    auth        required      pam_env.so
    auth        [success=done default=ignore authinfo_unavail=done]    pam_fprintd.so
    auth        required      pam_deny.so

    account     required      pam_unix.so
    account     sufficient    pam_localuser.so
    account     sufficient    pam_succeed_if.so uid < 500 quiet
    account     required      pam_permit.so

    password    required      pam_deny.so

    session     optional      pam_keyinit.so revoke
    session     required      pam_limits.so
    -session     optional      pam_systemd.so
    session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
    session     required      pam_unix.so
    EOF
