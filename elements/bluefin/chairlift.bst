kind: manual

# System side of ChairLift (Control Center). The GUI is a user-scoped
# Homebrew cask, which cannot place root-owned files, so the image ships the
# fixed-path privileged helper, its PolicyKit policy, and the GSettings
# schemas from the same checksummed release archive the cask installs.
# The helper path is pinned by the policy's exec.path annotation. Keep this
# release in step with the cask's version (ublue-os/homebrew-tap
# Casks/chairlift.rb). The bootc policy and /usr/share/chairlift/config.yml
# come from common.bst.
sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: github_files:projectbluefin/chairlift/releases/download/v26.10.4/chairlift_26.10.4_linux_amd64.tar.gz
      ref: be9824c2caa368cdf8f35a99dd18871076fb3db003cfb62e3c63b43439ff834a
  - arch == "aarch64":
      url: github_files:projectbluefin/chairlift/releases/download/v26.10.4/chairlift_26.10.4_linux_arm64.tar.gz
      ref: c38a0df47dc107527b3686610192602db1dcff51375cc5874115fcdf47c57028
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
