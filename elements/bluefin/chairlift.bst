kind: manual

# System side of ChairLift (Control Center). The GUI is a user-scoped
# Homebrew cask, which cannot place root-owned files, so the image ships the
# fixed-path privileged helper, its PolicyKit policy, and the GSettings
# schemas from the same checksummed release archive the cask installs.
# The helper path is pinned by the policy's exec.path annotation. Keep this
# release in step with the cask's version (projectbluefin/homebrew-tap
# Casks/chairlift.rb). The bootc policy and /usr/share/chairlift/config.yml
# come from common.bst.
sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: github_files:projectbluefin/chairlift/releases/download/v26.11.2/chairlift_26.11.2_linux_amd64.tar.gz
      ref: 173a0064d8c93faf61404aa75303686a50b83bf5f2eeda677f729ef8655b5556
  - arch == "aarch64":
      url: github_files:projectbluefin/chairlift/releases/download/v26.11.2/chairlift_26.11.2_linux_arm64.tar.gz
      ref: a0a0d79de23075d410af9b4ddbf2e4e5ecd1321c60c8ffd801405332da7c36a5
  base-dir: ""

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

depends:
- freedesktop-sdk.bst:components/polkit.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 -t "%{install-root}%{bindir}" chairlift-helper
  - |
    install -Dm644 -t "%{install-root}%{datadir}/polkit-1/actions" \
      data/io.projectbluefin.chairlift.ublue.policy
  - |
    install -Dm644 -t "%{install-root}%{datadir}/glib-2.0/schemas" \
      data/io.projectbluefin.chairlift.livery.gschema.xml \
      data/io.projectbluefin.chairlift.updates.gschema.xml \
      data/io.projectbluefin.chairlift.firstrun.gschema.xml
  - |
    %{install-extra}
