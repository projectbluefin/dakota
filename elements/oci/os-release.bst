# Base os-release (see include/os-release.yml); the nvidia variant
# shadows these files with its own repo names.
kind: manual

(@):
  - include/os-release.yml

variables:
  os-release-repo: dakota
  (?):
  - gaming == true:
      os-release-repo: dakota-gaming
