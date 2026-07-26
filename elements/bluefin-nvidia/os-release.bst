# Nvidia os-release: shadows the base identity files in the nvidia
# layer. The dep on the base element makes it stage first, so these
# files win the whitelisted overlap.
kind: manual

(@):
  - include/os-release.yml

depends:
  (>):
  - oci/os-release.bst

variables:
  os-release-repo: dakota-nvidia
  (?):
  - gaming == true:
      os-release-repo: dakota-nvidia-gaming

public:
  bst:
    overlap-whitelist:
      - /usr/lib/os-release
      - /etc/os-release
      - /usr/share/ublue-os/image-info.json
