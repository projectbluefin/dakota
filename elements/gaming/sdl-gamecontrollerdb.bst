# Community SDL controller mapping database.
#
# Bazzite and the OpenGamingCollective handheld/session work both treat
# controller coverage as table-stakes: Steam Input, SDL2/SDL3 games, and
# emulators all behave better when obscure pads have a known GUID mapping.
# This installs the upstream database in SDL's conventional data path so
# native host apps can opt into it; Flatpak apps usually carry their own
# runtime copy but also benefit from the host file when they talk to Steam
# Input or helper tools outside the sandbox.
kind: manual

sources:
- kind: remote
  # Pin to a commit instead of the moving master branch; this database is
  # updated frequently and raw-master fetches fail as soon as the content
  # hash changes.
  url: github-raw:mdqinc/SDL_GameControllerDB/f510b74438d08d7dd55ed06673f473bd1cc28b85/gamecontrollerdb.txt
  ref: 7d12b0f80d98e3f22077557be15736fae19b88557fc93369c564d6455249567c
  filename: gamecontrollerdb.txt

build-depends:
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/coreutils.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - install -Dm644 gamecontrollerdb.txt "%{install-root}/usr/share/sdl/gamecontrollerdb.txt"
