# Brother CUPS printer driver for monochrome laser printers.
kind: cmake

sources:
- kind: git_repo
  url: github:pdewacht/brlaser.git
  track: "v[0-9]*"
  ref: 23117fe9e0266396e4791cdae84d979928aed135 # v6 (peeled commit)

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst
- freedesktop-sdk.bst:components/cups.bst

depends:
- freedesktop-sdk.bst:components/cups.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  cmake-local: >-
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
