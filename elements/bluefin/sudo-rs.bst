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

config:
  build-commands:
  - cargo build --release

  install-commands:
  - install -Dm4755 target/release/sudo "%{install-root}/usr/bin/sudo"
  - ln -sr "%{install-root}/usr/bin/sudo" "%{install-root}/usr/bin/sudoedit"

sources:
- kind: git_repo
  url: github:memorysafety/sudo-rs.git
  track: 'v[0-9]*.[0-9]*.[0-9]*'
  ref: v0.2.13-0-g965cd7b99b04faf55819606178a5e8233cfd8b9e # v0.2.13
- kind: cargo2
  url: crates:crates
  ref:
  - kind: registry
    name: glob
    version: 0.3.3
    sha: 0cc23270f6e1808e30a928bdc84dea0b9b4136a8bc82338574f23baf47bbd280
  - kind: registry
    name: libc
    version: 0.2.183
    sha: b5b646652bf6661599e1da8901b3b9522896f01e736bad5f723fe7a3a27f899d
