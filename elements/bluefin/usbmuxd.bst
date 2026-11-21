kind: autotools
description: |
  Apple USB multiplexing daemon with upstream udev/systemd hotplug activation
  and pairing preflight support for GVfs AFC and wired Personal Hotspot.

sources:
# 1.1.1 is the latest tag but does not build against libplist 2.7.
- kind: git_repo
  url: github:libimobiledevice/usbmuxd.git
  track: master
  ref: 1.1.1-76-ge0216f30e1d34812354ee0cd6e91711bbf704bbe

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/git.bst
- freedesktop-sdk.bst:components/systemd.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/libusb.bst
- freedesktop-sdk.bst:components/openssl.bst
- gnome-build-meta.bst:core-deps/libplist.bst
- gnome-build-meta.bst:core-deps/libimobiledevice.bst

variables:
  conf-local: >-
    --sbindir=%{bindir}
    --localstatedir=/var
    --with-udevrulesdir=%{indep-libdir}/udev/rules.d
    --with-systemdsystemunitdir=%{indep-libdir}/systemd/system

config:
  install-commands:
    (>):
    - |
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/sysusers.d/usbmuxd.conf"
      cat > "%{install-root}%{indep-libdir}/sysusers.d/usbmuxd.conf" <<'EOF'
      u usbmux - "Apple USB multiplexing daemon" /var/lib/lockdown
      EOF
    - |
      # The image composition clears /var; create writable pairing state at boot.
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/tmpfiles.d/usbmuxd.conf"
      cat > "%{install-root}%{indep-libdir}/tmpfiles.d/usbmuxd.conf" <<'EOF'
      d /var/lib/lockdown 0700 usbmux usbmux -
      EOF
