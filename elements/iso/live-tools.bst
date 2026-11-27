# The ISO build script and its helpers (files/live-iso/). iso/tools.bst
# carries them, so iso/live.bst and `just iso IMAGE ORIGIN` run the same copy.
kind: import

sources:
  - kind: local
    path: files/live-iso

config:
  target: "%{libexecdir}/dakota-live-iso"
