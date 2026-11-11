kind: junction

sources:
- kind: git_repo
  url: github:apache/buildstream-plugins.git
  track: '*.*.*'
  exclude:
  - '*dev*'
  ref: 2.5.0-0-g79649529cffb695d0d22195ed9a4910c80ca6907
# apache/buildstream-plugins#91 (open upstream): the docker source only
# accepts Docker v2 media types, so registries serving OCI manifests
# (ghcr.io, used by bluefin/brew-tarball.bst) 404 on fetch. Drop the patch
# when the PR merges and the junction moves to a release containing it.
- kind: patch_queue
  path: patches/buildstream-plugins
