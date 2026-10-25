# The NVIDIA image: the cached base (oci/bluefin-nvidia-base.bst) plus the boot
# layer (oci/layers/bluefin-nvidia-boot.bst) as one additive top layer. Only
# the boot layer depends on secure_boot_signing, so the signing pass rebuilds
# it and this element while the base comes from the cache. See
# scripts/oci_append_layer.py for why build-oci's parent mode is not used.
kind: script

build-depends:
  # Shell and coreutils for the commands below; runtime-minimal carries
  # no shell since freedesktop-sdk 26.08.
  - core/sandbox-tools.bst
  - gnome-build-meta.bst:freedesktop-sdk.bst:components/oci-builder.bst
  - filename: oci/bluefin-nvidia-base.bst
    config:
      location: /base
  - filename: oci/layers/bluefin-nvidia-boot.bst
    config:
      location: /boot-layer
  - filename: oci/chunkah/bluefin-nvidia-boot.bst
    config:
      location: /ownership
  - filename: oci/chunkah-metadata-tool.bst
    config:
      location: /ownership-tool
  - filename: oci/oci-append-layer-tool.bst
    config:
      location: /append-tool

variables:
  ownership-variant: nvidia
  efi-arch: x64
  (?):
  - gaming == true:
      ownership-variant: nvidia-gaming
  - arch == "aarch64":
      efi-arch: aa64

config:
  commands:
    - |
      python3 /append-tool/oci-append-tool/oci_append_layer.py \
        --base /base --upper /boot-layer --output "%{install-root}" \
        --comment "Import Bluefin NVIDIA boot layer"

    # The boot layer may only add the paths below (plus their parent
    # directories). Keep the list exact: anything that needs a base setup
    # step (sysusers, ldconfig, schemas, presets) must stay in the base,
    # because those steps never see this layer. The required base paths
    # are what dakota-secure-boot runs, since the boot layer carries no
    # runtime dependencies.
    - |
      python3 /ownership-tool/ownership-tool/ownership_metadata.py finalize-overlay \
        --layout "%{install-root}" --base-layout /base \
        --base-sidecar /base/.dakota/ownership-final.json \
        --overlay-basis /ownership/ownership/basis.json \
        --allow-prefix /usr/lib/modules \
        --allow-prefix /usr/lib/dakota/secure-boot \
        --allow-prefix "%{indep-libdir}/systemd/boot/efi/systemd-boot%{efi-arch}.efi.signed" \
        --allow-prefix "%{libexecdir}/fwupd/efi/fwupd%{efi-arch}.efi.signed" \
        --allow-prefix /usr/lib/bootc/kargs.d/20-lockdown.toml \
        --allow-prefix /usr/libexec/dakota-secure-boot \
        --allow-prefix /usr/lib/systemd/system/dakota-secure-boot-update.service \
        --allow-prefix /usr/lib/systemd/system/multi-user.target.wants/dakota-secure-boot-update.service \
        --require-base-path /usr/bin/mokutil \
        --require-base-path /usr/bin/openssl \
        --require-base-path /usr/bin/efibootmgr \
        --require-base-path /usr/bin/bootctl \
        --require-base-path /usr/bin/systemd-cryptenroll \
        --require-base-path /usr/bin/od \
        --arch "%{go-arch}" --variant "%{ownership-variant}" \
        --output /ownership/final.json
      mkdir -p "%{install-root}/.dakota"
      cp /ownership/final.json "%{install-root}/.dakota/ownership-final.json"
