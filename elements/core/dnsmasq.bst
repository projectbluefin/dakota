# Override of freedesktop-sdk-extra's components/dnsmasq.bst: its make-args
# set only BINDIR, which drops the make plugin's PREFIX, so dnsmasq's Makefile
# default of /usr/local wins and the man page lands under /usr/local.
# Drop when freedesktop-sdk-extra passes PREFIX to dnsmasq itself.
kind: make

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  make-args: PREFIX=%{prefix} BINDIR=%{bindir}

sources:
- kind: git_repo
  url: thekelleys:dnsmasq.git
  track: 'v*.*'
  exclude:
  - '*test*'
  - '*rc*'
  ref: v2.93-0-g3ff66da573a77c8783deca10ec8c6bba07cd85e6
