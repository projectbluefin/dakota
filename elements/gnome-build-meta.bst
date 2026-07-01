kind: junction

sources:
- kind: git_repo
  url: gnome:gnome-build-meta.git
  track: master
  ref: 49-branchpoint-772-gc8394a030d18feb5cace6b871f80c19a9da04e4f
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

    # Override to track bootc ahead of gnome-build-meta upstream
    gnomeos-deps/bootc.bst: gnomeos-deps/bootc.bst

    gnomeos-deps/plymouth-gnome-theme.bst: bluefin/plymouth-bluefin-theme.bst

    # Replace the element so the OCI image generates Bluefin's os-release file
    oci/integration/os-release.bst: oci/os-release.bst

    # Override the signed kernel modules with the plain ones
    gnomeos/initramfs/signed-modules.bst: bluefin/unsigned-modules.bst

    plugins/buildstream-plugins.bst: plugins/buildstream-plugins.bst
    plugins/buildstream-plugins-community.bst: plugins/buildstream-plugins-community.bst
