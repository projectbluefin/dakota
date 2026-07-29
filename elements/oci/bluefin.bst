kind: script

build-depends:
  - gnome-build-meta.bst:freedesktop-sdk.bst:components/fakecap.bst
  - gnome-build-meta.bst:freedesktop-sdk.bst:components/oci-builder.bst
  - freedesktop-sdk.bst:components/glib.bst
  - gnome-build-meta.bst:core-deps/dconf.bst
  - gnome-build-meta.bst:freedesktop-sdk.bst:vm/prepare-image.bst
  - oci/layers/bluefin-init-scripts.bst
  - filename: oci/layers/bluefin.bst
    config:
      location: /layer

environment:
  LD_PRELOAD: /usr/libexec/fakecap/fakecap.so
  FAKECAP_DB: /fakecap

variables:
  sysroot-seed: b57666f6-0fe5-4310-adff-f256936d164d
  # Baked into org.opencontainers.image.ref.name: the `bootc upgrade`
  # origin. Gaming gets its own repo since tags are release channels.
  image-repo: dakota
  (?):
  - gaming == true:
      image-repo: dakota-gaming

config:
  commands:
    - mkdir /fakecap
    - |
      prepare-image.sh \
         --sysroot /layer \
         --initscripts /initial_scripts \
         --seed "%{sysroot-seed}" \
         --noroot --noboot >/dev/null

    - |
      systemd-sysusers --root /layer

    - |
      glib-compile-schemas /layer/usr/share/glib-2.0/schemas

    # bootc images must not have both /etc and /usr/etc.
    # /usr/etc is an ostree implementation detail generated client-side;
    # the image should only ship /etc.
    - |
      if [ -d /layer/usr/etc ]; then
        mkdir -p /layer/etc
        cp -a /layer/usr/etc/. /layer/etc/
        rm -rf /layer/usr/etc
      fi

    - |
      dconf update /layer/etc/dconf/db

    - |
      # Rebuild the shared library linker cache for the sysroot.
      # Without this, any SO version bump (e.g. Mesa libgallium, Pipewire)
      # leaves /etc/ld.so.cache stale after a `bootc switch`. The stale
      # cache causes dlopen() failures for the new SO name — silently
      # breaking the component on first boot with no obvious error.
      #
      # Reproducer: PR #497 junction bump Mesa 26.0.5 → 26.0.6 caused
      # GNOME Shell "No GPUs found" boot loop (GDM never started).
      # Root cause: dri_gbm.so has no RPATH and relied on the linker
      # cache to find libgallium-26.0.6.so, which was not yet in
      # /etc/ld.so.cache on the deployed system.
      ldconfig -r /layer -f /layer/etc/ld.so.conf

    - |
      cd "%{install-root}"
      build-oci <<EOF
      mode: oci
      gzip: disabled
      images:
      - os: linux
        architecture: "%{go-arch}"
        layer: /layer
        comment: "Import Bluefin layer"
        config:
          Labels:
            'com.github.containers.toolbox': 'true'
            'org.opencontainers.image.title': 'Bluefin'
            'org.opencontainers.image.description': 'A custom GNOME-based desktop image'
            'org.opencontainers.image.vendor': 'Project Bluefin'
            'org.opencontainers.image.licenses': 'Apache-2.0'
            'org.opencontainers.image.url': 'https://projectbluefin.io'
            'org.opencontainers.image.source': 'https://github.com/projectbluefin/dakota'
            'containers.bootc': '1'
        index-annotations:
          'org.opencontainers.image.ref.name': 'ghcr.io/projectbluefin/%{image-repo}:latest'
      EOF
