kind: junction

sources:
- kind: tar
  url: pypi:source/b/buildstream-plugins/buildstream-plugins-2.5.0.tar.gz
  ref: 49c57dec88c0b4558f474520c2e29c69ecd42a1e5c07423baae5b29b153e54a6
# apache/buildstream-plugins#91 (open upstream): the docker source only
# accepts Docker v2 media types, so registries serving OCI manifests
# (ghcr.io, used by bluefin/brew-tarball.bst) 404 on fetch. Drop the patch
# when the PR merges and the junction moves to a release containing it.
- kind: patch_queue
  path: patches/buildstream-plugins
