# Only the regex component needed by librime; Boost.Regex is header-only.
kind: manual

sources:
- kind: anitya
  project-id: 6845
  url: boost:release/{version}/source/boost_{major}_{minor}_{patch}.tar.bz2
  ref:
    version: 1.92.0
    sha256sum: 5c1d40cb8e19adbf740a4ec2da35b3e58f3f5804b1dce44deb53df72193cbc6c
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
