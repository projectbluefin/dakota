kind: compose
build-depends:
  - freedesktop-sdk.bst:components/python3.bst
  - freedesktop-sdk.bst:components/ca-certificates.bst
  - freedesktop-sdk.bst:components/tzdata.bst
config:
  exclude:
    - devel
    - debug
    - doc
    - locale
  include-orphans: true
