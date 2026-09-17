kind: manual

sources:
- kind: remote
  filename: umotd
  (?):
  - arch == "x86_64":
      url: github_files:projectbluefin/umotd/releases/download/v0.3.2/umotd_0.3.2_linux_amd64
      ref: eddae399e87ed5d7a3ccc2fdc2e51e4cf183281ac29ed36621f3c16393c048cb
  - arch == "aarch64":
      url: github_files:projectbluefin/umotd/releases/download/v0.3.2/umotd_0.3.2_linux_arm64
      ref: fd3c09c9edb47e68d897569daef7e1d9e7d100148848b349c76f20e3855fb9e0
- kind: remote
  url: https://raw.githubusercontent.com/projectbluefin/umotd/97520c61e8fca7eae7359bf3d329542078f17412/LICENSE
  filename: LICENSE
  ref: c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm755 umotd "%{install-root}%{bindir}/umotd"
  - install -Dm644 LICENSE "%{install-root}%{datadir}/licenses/umotd/LICENSE"
