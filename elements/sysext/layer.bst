kind: script

build-depends:
- gnome-build-meta.bst:freedesktop-sdk.bst:components/fakecap.bst
- gnome-build-meta.bst:freedesktop-sdk.bst:components/jq.bst
- gnome-build-meta.bst:freedesktop-sdk.bst:vm/prepare-image.bst
- gnome-build-meta.bst:gnomeos/make-layer.bst
- freedesktop-sdk.bst:components/glib.bst
- gnome-build-meta.bst:core-deps/dconf.bst
- gnome-build-meta.bst:gnomeos/usr/initial-scripts.bst
- sysext/initial-scripts.bst
- filename: gnome-build-meta.bst:gnomeos/usr/filesystem.bst
  config:
    location: '/sysroot'
- filename: sysext/filesystem.bst
  config:
    location: '/sysroot-bluefin'
- filename: sysext/signing-keys.bst
  config:
    location: '/keys'

variables:
  # Mirrored from gnome-build-meta include/image-version.yml since
  # these are scoped to the junction and not inherited by our project.
  image-version: 'l.1'
  filesystem-time: 1321009871
  sysroot-seed: a1c3e5f7-2b4d-6f80-9a1c-3e5f72b4d6f8
  repart-seed: d8f6b4a2-0c1e-3d5f-7a9b-2c4e6d8f0a1b
  confext-repart-seed: e9a7c5b3-1d0f-4e6a-8b2c-5d7f9a1b3c4e
  strip-binaries: ''
  work: /buildstream

environment:
  EROFS_OPTIONS: -z zstd --all-time -T %{filesystem-time} -E fragments,fragdedupe=inode
  EROFS_WORKERS: --workers=%{max-jobs}
  LD_PRELOAD: /usr/libexec/fakecap/fakecap.so
  FAKECAP_DB: /fakecap

environment-nocache:
- EROFS_WORKERS

config:
  commands:
  - mkdir /fakecap
  - mkdir -p "%{work}"
  - cp -a /sysroot "%{work}/sysroot"
  - cp -a /sysroot-bluefin "%{work}/sysroot-bluefin"

  # Run prepare-image.sh on the base GNOME OS sysroot
  - |
    prepare-image.sh \
       --sysroot "%{work}/sysroot" \
       --initscripts /etc/fdsdk/initial_scripts \
       --seed "%{sysroot-seed}" \
       --noroot --noboot --nodepmod >/dev/null

  # Run prepare-image.sh on the Bluefin sysroot
  - |
    prepare-image.sh \
       --sysroot "%{work}/sysroot-bluefin" \
       --initscripts /etc/fdsdk/initial_scripts-bluefin \
       --seed "%{sysroot-seed}" \
       --noroot --noboot --nodepmod >/dev/null

  # Compile gsettings schemas on the Bluefin sysroot
  - |
    glib-compile-schemas "%{work}/sysroot-bluefin/usr/share/glib-2.0/schemas"

  # Merge /usr/etc into /etc on the Bluefin sysroot (same as oci/bluefin.bst)
  - |
    if [ -d "%{work}/sysroot-bluefin/usr/etc" ]; then
      mkdir -p "%{work}/sysroot-bluefin/etc"
      cp -a "%{work}/sysroot-bluefin/usr/etc/." "%{work}/sysroot-bluefin/etc/"
      rm -rf "%{work}/sysroot-bluefin/usr/etc"
    fi

  # Compile dconf database
  - |
    dconf update "%{work}/sysroot-bluefin/etc/dconf/db"

  # Create tmpfiles.d config for /etc paths that come from the confext.
  # These tell systemd-tmpfiles to create symlinks from /etc to the
  # factory defaults shipped in /usr/share/factory/etc.
  - |
    cat >"%{work}/sysroot-bluefin/usr/lib/tmpfiles.d/extra-etc-bluefin.conf"<<EOF
    L /etc/dconf
    L /etc/containers
    L /etc/environment
    EOF

  # Write extension-release metadata for the sysext
  - |
    mkdir -p "%{work}/sysroot-bluefin/usr/lib/extension-release.d"
    case "%{branch}" in
      master|main)
        version_id=Nightly
        ;;
      *)
        version_id="%{branch}"
        ;;
    esac

    cat <<EOF >"%{work}/sysroot-bluefin/usr/lib/extension-release.d/extension-release.bluefin_%{image-version}"
    ID="org.gnome.os"
    VERSION_ID="${version_id}"
    SYSEXT_LEVEL="%{image-version}"
    EOF

  # Diff /usr: produce only the delta between base and Bluefin.
  # Wraps make-layer with a Python patch to handle mknod PermissionError
  # gracefully in rootless containers. Whiteout (CHR 0:0) creation fails
  # in user namespaces -- we write zero-byte sentinel files instead since
  # systemd-repart --make-ddi repacks the tree into an EROFS image anyway.
  - |
    mkdir -p "%{work}/output"
    python3 -c "
    import os, stat, sys
    # Monkey-patch os.mknod to fall back to a zero-byte file on EPERM
    _real_mknod = os.mknod
    def _safe_mknod(path, mode=0o600, device=0, *, dir_fd=None):
        try:
            _real_mknod(path, mode, device, dir_fd=dir_fd) if dir_fd else _real_mknod(path, mode, device)
        except PermissionError:
            # Cannot create char device in userns -- write a zero-byte sentinel.
            # The sysext DDI builder (systemd-repart) repacks the tree, so
            # overlayfs whiteout semantics are not needed in the output dir.
            open(path, 'w').close()
            os.chmod(path, stat.S_IRUSR | stat.S_IWUSR)
    os.mknod = _safe_mknod
    sys.argv = ['make-layer', '%{work}/sysroot/usr', '%{work}/sysroot-bluefin/usr', '%{work}/output/usr']
    exec(open('/usr/bin/make-layer').read())
    "

  # Diff /etc: produce the delta for the confext.
  # Output is output/etc/etc/... because make-layer preserves the tree
  # structure relative to the given roots.
  - |
    mkdir -p "%{work}/output/etc"
    python3 -c "
    import os, stat, sys
    _real_mknod = os.mknod
    def _safe_mknod(path, mode=0o600, device=0, *, dir_fd=None):
        try:
            _real_mknod(path, mode, device, dir_fd=dir_fd) if dir_fd else _real_mknod(path, mode, device)
        except PermissionError:
            open(path, 'w').close()
            os.chmod(path, stat.S_IRUSR | stat.S_IWUSR)
    os.mknod = _safe_mknod
    sys.argv = ['make-layer', '%{work}/sysroot/etc', '%{work}/sysroot-bluefin/etc', '%{work}/output/etc/etc']
    exec(open('/usr/bin/make-layer').read())
    "

  # Extract /etc paths listed in tmpfiles.d as factory defaults.
  # These go into /usr/share/factory/etc so systemd-tmpfiles can
  # populate /etc from them at boot.
  - |
    mkdir -p "%{work}/output/factory"
    for p in $(grep -v "^#" <"%{work}/sysroot-bluefin/usr/lib/tmpfiles.d/extra-etc-bluefin.conf" | grep -v "^$" | cut -d" " -f2); do
      if [ -e "%{work}/output/etc${p}" ]; then
        mkdir -p "$(dirname "%{work}/output/factory${p}")"
        cp -rlTP "%{work}/output/etc${p}" "%{work}/output/factory${p}"
        rm -rf "%{work}/output/etc${p}"
      fi
    done

  - |
    mkdir -p "%{work}/output/usr/share/factory/etc"
    if [ -d "%{work}/output/factory/etc" ] && [ "$(ls -A "%{work}/output/factory/etc")" ]; then
      cp -rlTP "%{work}/output/factory" "%{work}/output/usr/share/factory"
    fi

  # Copy os-release into the sysext /etc
  - |
    mkdir -p "%{work}/output/etc"
    cp -T "%{work}/sysroot-bluefin/usr/lib/os-release" "%{work}/output/etc/os-release"

  # Build sysext DDI (covers /usr delta)
  - |
    mkdir -p "%{work}/tmp"

  - |
    TMPDIR='%{work}/tmp' \
    SYSTEMD_LOG_LEVEL=debug \
    SYSTEMD_REPART_MKFS_OPTIONS_EROFS="${EROFS_OPTIONS} ${EROFS_WORKERS}" \
      systemd-repart \
        --empty=create \
        --make-ddi=sysext \
        --size=auto \
        --dry-run=no \
        --discard=no \
        --offline=true \
        --no-pager \
        --private-key=/keys/SYSEXT.key \
        --certificate=/keys/SYSEXT.crt \
        --seed %{repart-seed} \
        --copy-source="%{work}/output" \
        "%{work}/bluefin-%{systemd-arch}_%{image-version}.raw"

  # Build confext DDI (covers /etc delta)
  - |
    mkdir -p "%{work}/confext-output/etc"
    if [ -d "%{work}/output/etc/etc" ] && [ "$(ls -A "%{work}/output/etc/etc")" ]; then
      cp -a "%{work}/output/etc/etc/." "%{work}/confext-output/etc/"
    fi

    # Write extension-release for the confext
    mkdir -p "%{work}/confext-output/etc/extension-release.d"
    case "%{branch}" in
      master|main)
        version_id=Nightly
        ;;
      *)
        version_id="%{branch}"
        ;;
    esac

    cat <<EOF >"%{work}/confext-output/etc/extension-release.d/extension-release.bluefin-confext_%{image-version}"
    ID="org.gnome.os"
    VERSION_ID="${version_id}"
    CONFEXT_LEVEL="%{image-version}"
    EOF

  - |
    TMPDIR='%{work}/tmp' \
    SYSTEMD_LOG_LEVEL=debug \
    SYSTEMD_REPART_MKFS_OPTIONS_EROFS="${EROFS_OPTIONS} ${EROFS_WORKERS}" \
      systemd-repart \
        --empty=create \
        --make-ddi=confext \
        --size=auto \
        --dry-run=no \
        --discard=no \
        --offline=true \
        --no-pager \
        --private-key=/keys/SYSEXT.key \
        --certificate=/keys/SYSEXT.crt \
        --seed %{confext-repart-seed} \
        --copy-source="%{work}/confext-output" \
        "%{work}/bluefin-confext-%{systemd-arch}_%{image-version}.raw"

  # Move DDIs to install root
  - |
    mv "%{work}/bluefin-%{systemd-arch}_%{image-version}.raw" "%{install-root}"
    mv "%{work}/bluefin-confext-%{systemd-arch}_%{image-version}.raw" "%{install-root}"
