# Only the regex component needed by librime; Boost.Regex is header-only.
kind: manual

sources:
- kind: anitya
  project-id: 6845
  url: boost:release/{version}/source/boost_{major}_{minor}_{patch}.tar.bz2
  ref:
    version: 1.90.0
    sha256sum: 49551aff3b22cbc5c5a9ed3dbc92f0e23ea50a0f7325b0d198b705e8ee3fc305

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

environment:
  MAXJOBS: "%{max-jobs}"

environment-nocache:
- MAXJOBS

config:
  configure-commands:
  - ./bootstrap.sh --with-libraries=regex
  build-commands:
  - ./b2 --with-regex -j"${MAXJOBS}" variant=release threading=multi link=shared
  install-commands:
  - ./b2 --with-regex variant=release threading=multi link=shared --prefix=%{install-root}%{prefix} --libdir=%{install-root}%{libdir} install
  - install -Dm644 LICENSE_1_0.txt %{install-root}%{datadir}/licenses/boost/LICENSE_1_0.txt
