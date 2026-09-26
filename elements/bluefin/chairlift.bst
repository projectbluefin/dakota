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
      url: github_files:projectbluefin/chairlift/releases/download/v26.09.0-alpha.2/chairlift_26.09.0-alpha.2_linux_amd64.tar.gz
      ref: 18f630bb7de0e921ba12ae8c0650adf5e550b0cde203938d73d534382f196d08
  - arch == "aarch64":
      url: github_files:projectbluefin/chairlift/releases/download/v26.09.0-alpha.2/chairlift_26.09.0-alpha.2_linux_arm64.tar.gz
      ref: cb64663a0e2ae87b049bacd431de9d9c1925833006559c8310f8bd53ec938a86
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
    install -Dm755 -t "%{install-root}%{bindir}" chairlift-ublue-helper
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
