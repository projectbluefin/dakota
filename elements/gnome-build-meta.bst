kind: junction

sources:
- kind: git_repo
  url: gnome:gnome-build-meta.git
  track: gnome-51
  ref: 51.1-3-g24bd9e3394437b85fc204bf58ecd3d867d815f66
- kind: patch_queue
  path: patches/gnome-build-meta

config:
  options:
    arch: '%{arch}'
    (?):
    - x86_64_v3:
        x86_64_v3: true

  overrides:
    # This along with the patches is required and has to match what gnome-build-meta is using
    freedesktop-sdk.bst: freedesktop-sdk.bst

    # Replace the element so the OCI image doesn't have any apps
    core/meta-gnome-core-apps.bst: core/meta-gnome-core-apps.bst

    # Override to track bootc ahead of gnome-build-meta upstream (gnome-50 is at v1.12.1)
    # Remove when gnome-50 ships bootc >= v1.15.1 and files are identical
    gnomeos-deps/bootc.bst: gnomeos-deps/bootc.bst

    # Install dnsmasq under %{prefix}; see the element for the exit condition
    freedesktop-sdk-extra.bst:components/dnsmasq.bst: core/dnsmasq.bst

    gnomeos-deps/plymouth-gnome-theme.bst: bluefin/plymouth-bluefin-theme.bst

    # Replace the element so the OCI image generates Bluefin's os-release file
    oci/integration/os-release.bst: oci/os-release.bst

    # Kernel modules: signed in publish builds, plain everywhere else
    gnomeos/initramfs/signed-modules.bst: bluefin/unsigned-modules.bst
    (?):
    - secure_boot_signing == true:
        gnomeos/initramfs/signed-modules.bst: bluefin/signed-modules.bst

    plugins/buildstream-plugins.bst: plugins/buildstream-plugins.bst
    plugins/buildstream-plugins-community.bst: plugins/buildstream-plugins-community.bst
