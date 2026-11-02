kind: manual

sources:
- kind: remote
  filename: umotd
  (?):
  - arch == "x86_64":
      url: github_files:projectbluefin/umotd/releases/download/v0.3.3/umotd_0.3.3_linux_amd64
      ref: 76a2452c669db4e8426b822ccab4429579c8ef2977b20bafa4d2f2de4b545a30
  - arch == "aarch64":
      url: github_files:projectbluefin/umotd/releases/download/v0.3.3/umotd_0.3.3_linux_arm64
      ref: a8337de651abb2657947c30a61515542323a2677d279d05c39efbbe4d2d72730
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
