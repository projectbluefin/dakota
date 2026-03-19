kind: junction

sources:
- kind: git_repo
  url: gnome:gnome-build-meta.git
  track: master
  ref: 49-branchpoint-538-g8a5eb51a9629804a4f6e58de8dd2d814ae2dbc49
- kind: patch_queue
  path: patches/gnome-build-meta

config:
  overrides:
    # This along with the patches is required and has to match what gnome-build-meta is using
    freedesktop-sdk.bst: freedesktop-sdk.bst

    # Replace the element so the OCI image doesn't have any apps
    core/meta-gnome-core-apps.bst: core/meta-gnome-core-apps.bst

    gnomeos-deps/plymouth-gnome-theme.bst: bluefin/plymouth-bluefin-theme.bst

    # Replace the element so the OCI image generates Bluefin's os-release file
    oci/integration/os-release.bst: oci/os-release.bst

    plugins/buildstream-plugins.bst: plugins/buildstream-plugins.bst
    plugins/buildstream-plugins-community.bst: plugins/buildstream-plugins-community.bst
