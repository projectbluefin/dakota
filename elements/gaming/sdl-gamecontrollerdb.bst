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
  url: github-raw:mdqinc/SDL_GameControllerDB/998d5b08b5b33bdf3a63b2ef8f2ac4ccc664e2f6/gamecontrollerdb.txt
  ref: a34670ad1dafedef740c6c8ae8b8ff82a1cf1058d8f98eb8f1c123dee905ad19
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
