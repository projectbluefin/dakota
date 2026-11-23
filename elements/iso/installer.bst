# The installer and the live session's settings, as the tree that
# files/live-iso/build.py lays into the ISO's /etc and /var. It ships on
# the ISO only: nothing here is in the image, and the installer removes it
# after the install (cleanup-paths is its list).
kind: manual

build-depends:
  - core/sandbox-tools.bst
  - freedesktop-sdk.bst:components/findutils.bst
  - freedesktop-sdk.bst:components/grep.bst
  - freedesktop-sdk.bst:components/glib.bst
  - gnome-build-meta.bst:core-deps/dconf.bst

sources:
  - kind: local
    path: files/live-iso/installer

variables:
  tree: "%{install-root}%{datadir}/dakota-live-installer"
  strip-binaries: ""

config:
  build-commands:
    - |
      glib-compile-resources --sourcedir=ui \
        --target=org.gnome.Installer.gresource ui/gresources.xml
      mkdir dconf.d
      cp data/dconf-live.ini dconf.d/live
      dconf compile dconf-user dconf.d

  install-commands:
    - |
      etc="%{tree}/etc" var="%{tree}/var"
      install -Dm755 -t "$var/opt/dakota-installer" daemon.py cleanup.py ui/installer.py
      install -Dm644 -t "$var/opt/dakota-installer" disks.py
      install -Dm644 -t "$var/opt/dakota-installer" org.gnome.Installer.gresource
      install -Dm644 -t "$etc/xdg/autostart" data/org.projectbluefin.Installer.desktop
      install -Dm644 -t "$etc/dbus-1/system.d" data/org.gnome.Installer1.conf
      install -Dm644 -t "$etc/systemd/system" data/dakota-installer.service \
        data/dakota-live-cleanup.service
      mkdir -p "$etc/systemd/system/multi-user.target.wants"
      ln -s ../dakota-installer.service ../dakota-live-cleanup.service \
        "$etc/systemd/system/multi-user.target.wants/"
      install -Dm644 data/dakota-live.tmpfiles "$etc/tmpfiles.d/dakota-live.conf"
      install -Dm644 data/accountsservice-live "$var/lib/AccountsService/users/live"

      # The live user: initial setup is already done, the tour stays closed,
      # and no secret service runs, so nothing asks a passwordless user to
      # unlock a keyring.
      home="$var/home/live"
      install -Dm644 dconf-user "$home/.config/dconf/user"
      # The installer starts with the session. This entry puts it in the
      # live user's app grid too, to open it again after "Try Bluefin".
      install -Dm644 -t "$home/.local/share/applications" data/org.projectbluefin.Installer.desktop
      echo yes >"$home/.config/gnome-initial-setup-done"
      mkdir -p "$home/.config/systemd/user"
      for unit in oo7-daemon.service oo7-portal.service gnome-keyring-daemon.service \
                  gnome-keyring-daemon.socket dbus-org.freedesktop.secrets.service; do
        ln -s /dev/null "$home/.config/systemd/user/$unit"
      done

      # What cleanup.py removes on the installed system's first boot: every
      # file and link added here, as paths on the running system, plus the
      # directories that are this tree's alone.
      (
        cd "%{tree}"
        find etc var \( -type f -o -type l \) ! -path 'var/home/live/*' -printf '/%p\n'
        echo /var/home/live
        echo /var/opt/dakota-installer
      ) >cleanup-paths.unsorted
      LC_ALL=C sort cleanup-paths.unsorted >cleanup-paths
      # An empty list would leave the installer on every installed system.
      grep -qx /etc/systemd/system/dakota-installer.service cleanup-paths
      grep -qx /etc/systemd/system/dakota-live-cleanup.service cleanup-paths
      install -Dm644 -t "$var/opt/dakota-installer" cleanup-paths
