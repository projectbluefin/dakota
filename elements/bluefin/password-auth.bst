kind: manual

# Dakota override of freedesktop-sdk's /etc/pam.d/password-auth.
#
# One change from the stock file (fdsdk components/linux-pam.bst,
# files/linux-pam-config/password-auth): the auth pam_unix line uses
# `nullresetok` instead of `nullok_secure`, the same as
# bluefin/fprintd-system-auth.bst does for system-auth. Upstream Linux-PAM
# reads `nullok_secure` as plain `nullok`; `nullresetok` accepts an empty
# password only while a password change is enforced, which GNOME's "set a
# password at next login" needs. The password lines are unchanged.
#
# Users of this stack: gdm-password (GDM login and the lock screen), sshd,
# vmtoolsd.
#
# Like fprintd-system-auth.bst, this depends on components/linux-pam.bst so
# it stages after the stock file and wins the overlap.
#
# Exit condition: drop once fdsdk ships password-auth without nullok/
# nullok_secure on the auth line. Re-check at every fdsdk bump that the rest
# of the file still matches upstream's password-auth.

public:
  bst:
    overlap-whitelist:
    - /etc/pam.d/password-auth

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

depends:
- freedesktop-sdk.bst:components/linux-pam.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm644 /dev/null "%{install-root}%{sysconfdir}/pam.d/password-auth"
    cat > "%{install-root}%{sysconfdir}/pam.d/password-auth" <<'EOF'
    auth        required      pam_env.so
    -auth       sufficient    pam_systemd_home.so
    auth        sufficient    pam_unix.so try_first_pass nullresetok
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
