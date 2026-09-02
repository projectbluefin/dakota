kind: make

public:
  bst:
    overlap-whitelist:
    - /usr/bin/sudo
    - /usr/bin/sudoedit
    - /usr/lib/debug/usr/bin/sudo.debug

build-depends:
- freedesktop-sdk.bst:components/rust.bst
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
- freedesktop-sdk.bst:components/linux-pam.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/linux-pam.bst

variables:
  strip-binaries: ""

config:
  build-commands:
  - cargo build --release

  install-commands:
  - install -Dm4755 target/release/sudo "%{install-root}/usr/bin/sudo"
  - ln -sr "%{install-root}/usr/bin/sudo" "%{install-root}/usr/bin/sudoedit"
  - '%{install-extra}'

sources:
- kind: git_repo
  url: github:memorysafety/sudo-rs.git
  track: 'v[0-9]*.[0-9]*.[0-9]*'
  ref: v0.2.15-0-ge4cfa9cf7b71e287dd5046633c0f5276072d147d # v0.2.13
- kind: cargo2
  url: crates:crates
  ref:
  - kind: registry
    name: glob
    version: 0.3.4
    sha: e4eba85ea1d0a966a983acd07deee566e67395d2d96b6fb39e62b5a833f1eb0b
  - kind: registry
    name: libc
    version: 0.2.189
    sha: 3eaf3ede3fee6db1a4c2ee091bf8a8b4dccdc6d17f656fb07896ee72867612f2
