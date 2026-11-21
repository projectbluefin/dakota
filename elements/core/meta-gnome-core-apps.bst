# Derived from gnome-build-meta.bst 50~ core/meta-gnome-core-apps.bst

kind: stack
description: |
  Overridden to only keep some applications.

depends:
  # Baobab is preinstalled from Flathub as org.gnome.baobab instead.
  - gnome-build-meta.bst:core/gnome-disk-utility.bst
  - gnome-build-meta.bst:core/nautilus.bst
