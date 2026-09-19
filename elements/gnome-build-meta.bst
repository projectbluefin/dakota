kind: junction

sources:
- kind: git_repo
  url: gnome:gnome-build-meta.git
  track: master
  ref: 49-branchpoint-991-ge4880a4fa779a7a42a0fe7225be94449aa5aa490

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

    gnomeos-deps/plymouth-gnome-theme.bst: bluefin/plymouth-bluefin-theme.bst

    # Replace the element so the OCI image generates Bluefin's os-release file
    oci/integration/os-release.bst: oci/os-release.bst

    # Override the signed kernel modules with the plain ones
    gnomeos/initramfs/signed-modules.bst: bluefin/unsigned-modules.bst

    plugins/buildstream-plugins.bst: plugins/buildstream-plugins.bst
    plugins/buildstream-plugins-community.bst: plugins/buildstream-plugins-community.bst
