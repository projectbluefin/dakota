# Only the regex component needed by librime; Boost.Regex is header-only.
kind: manual

sources:
- kind: tar
  url: boost:release/1.90.0/source/boost_1_90_0.tar.bz2
  ref: 49551aff3b22cbc5c5a9ed3dbc92f0e23ea50a0f7325b0d198b705e8ee3fc305

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

config:
  configure-commands:
  - ./bootstrap.sh --with-libraries=regex
  build-commands:
  - ./b2 --with-regex -j%{max-jobs} variant=release threading=multi link=shared
  install-commands:
  - ./b2 --with-regex variant=release threading=multi link=shared --prefix=%{install-root}%{prefix} --libdir=%{install-root}%{libdir} install
  - install -Dm644 LICENSE_1_0.txt %{install-root}%{datadir}/licenses/boost/LICENSE_1_0.txt
