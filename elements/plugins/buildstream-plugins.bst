kind: junction

sources:
- kind: git_repo
  url: github:apache/buildstream-plugins.git
  track: '*.*.*'
  exclude:
  - '*dev*'
  ref: 2.8.0-0-g2681232038711d5c3d4ef1ecc962321c33ec72c1
# OCI manifest types landed upstream (apache/buildstream-plugins#105), so the
# docker-source OCI 404 patch is no longer needed at 2.8.0.
