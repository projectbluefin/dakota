kind: manual

# Dakota override of freedesktop-sdk's /etc/pam.d/system-auth (issue #953).
#
# WHY A FULL-FILE OVERRIDE:
# PAM has no drop-in / .d mechanism for the aggregate `system-auth` stack, so
# the only way to add fingerprint auth to everything that `include`s it is to
# ship a complete replacement file. fdsdk's `components/linux-pam.bst` installs
# the stock file to %{sysconfdir}/pam.d/system-auth (sysconfdir=/etc), with no
# fingerprint line. There is NO authselect on this image — `authselect
# select ... with-fingerprint` is not available — so the file must be edited
# statically at build time.
#
# WHAT THIS FIXES:
# sudo (/etc/pam.d/sudo), polkit (/usr/lib/pam.d/polkit-1) and su all reach
# their auth stack via `auth include system-auth`. Enrollment and GDM already
# work because gdm-fingerprint / fingerprint-auth reference pam_fprintd
# directly; system-auth never did, so sudo and polkit never offered a finger.
# Adding one line here lights up fingerprint for every system-auth consumer at
# once.
#
# ORDERING CONTRACT (do not reorder):
#   * pam_fprintd.so sits ABOVE pam_unix.so — the reader is offered first.
#   * It is `sufficient`, not `required`: a fingerprint match short-circuits to
#     success, but ANY failure (no match, no reader, no enrolled prints) falls
#     through to pam_unix so the password remains a full fallback. It can never
#     lock anyone out.
#   * It sits directly after pam_env, mirroring fdsdk's own fingerprint-auth
#     file, and before the systemd-homed line — homed users still get their
#     password path via the `-auth sufficient pam_systemd_home.so` below.
#
# NO-READER LATENCY:
# pam_fprintd asks fprintd (net.reactivated.Fprint) for devices over D-Bus. On
# a machine with NO reader, GetDevices() returns empty and the module returns
# PAM_AUTHINFO_UNAVAIL immediately — it does NOT block. The ~30s wait only
# occurs when a reader IS present and the module is waiting for a swipe (and
# even then it times out and falls through to the password). So this line adds
# no perceptible delay to sudo/polkit on reader-less hardware. (Verify on real
# no-reader hardware — see PR notes; the dev machine has no reader.)
#
# OVERRIDE MECHANICS:
# This element depends on components/linux-pam.bst so it stages AFTER the stock
# file and wins the compose overlap; overlap-whitelist silences the (expected)
# overlap warning. The file lands in /etc (not /usr/etc), so the OCI
# `/usr/etc -> /etc` merge in oci/bluefin.bst never touches or clobbers it.
#
# Exit condition: drop if fdsdk/gnome-build-meta ship a fingerprint-enabled
# system-auth, or if the image gains authselect. Re-check at every fdsdk bump
# that the stock auth/account/password/session stack below still matches
# upstream (diff against files/linux-pam-config/system-auth in the fdsdk ref) —
# if upstream changes system-auth, this copy must be re-synced.

public:
  bst:
    overlap-whitelist:
    - /etc/pam.d/system-auth

# No external sources — the file is inline.
build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

# Stage after the stock file so this override wins the overlap deterministically.
depends:
- freedesktop-sdk.bst:components/linux-pam.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm644 /dev/stdin "%{install-root}%{sysconfdir}/pam.d/system-auth" <<'EOF'
    auth        required      pam_env.so
    auth        sufficient    pam_fprintd.so
    -auth       sufficient    pam_systemd_home.so
    auth        sufficient    pam_unix.so try_first_pass nullok_secure
    auth        required      pam_deny.so

    -account    sufficient    pam_systemd_home.so
    account     required      pam_unix.so

    -password   sufficient    pam_systemd_home.so
    password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
    password    sufficient    pam_unix.so try_first_pass use_authtok nullok_secure sha512 shadow
    password    required      pam_deny.so

    -session    optional      pam_systemd_home.so
    session     optional      pam_keyinit.so revoke
    session     required      pam_limits.so
    -session     optional      pam_systemd.so
    session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
    session     required      pam_unix.so
    EOF
