kind: autotools
description: |
  ALSA mixer state save/restore.

  freedesktop-sdk ships alsa-lib (libasound) but no alsa-utils, so the image
  has no alsactl, no alsa-restore/alsa-state systemd units and no
  90-alsa-restore.rules. Nothing restores the kernel mixer state across
  reboots, and the /usr/share/alsa/init initialisation database is absent.
  On hardware whose power-on mixer defaults are muted or mis-routed
  (auto-mute, amp-enable, IEC958, output selection) this surfaces as
  "boots with broken sound" (projectbluefin/dakota#1027).

  We build alsa-utils and keep only the mixer-state machinery: the alsactl
  binary, its systemd units (statically enabled via sound.target.wants/ by
  `make install`), the udev rule that restores per-card state on hotplug, and
  the init database.

sources:
- kind: tar
  # Canonical upstream release tarball (alsa-project.org). ref is the sha256
  # of alsa-utils-1.2.14.tar.bz2, verified by fetching the tarball and running
  # sha256sum.
  #
  # LOCKSTEP CONSTRAINT: alsa-utils and alsa-lib release together and the utils
  # require the matching libasound ABI/API. This MUST track fdsdk's alsa-lib
  # (freedesktop-sdk.bst:components/alsa-lib.bst), currently 1.2.14. Building a
  # newer alsa-utils against 1.2.14 fails (e.g. 1.2.16 needs snd_lib_log_*
  # from alsa-lib 1.2.16). Bump this in the same change as any fdsdk alsa-lib
  # bump, never independently.
  url: alsa_project:utils/alsa-utils-1.2.14.tar.bz2
  ref: 0794c74d33fed943e7c50609c13089e409312b6c403d6ae8984fc429c0960741

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/alsa-lib.bst
- freedesktop-sdk.bst:components/systemd.bst
- freedesktop-sdk.bst:components/pkg-config.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/alsa-lib.bst

variables:
  # alsactl is a sbin_PROGRAM and the units/udev rule bake in @sbindir@. This
  # is a merged-usr image (/usr/sbin -> bin), so installing into a real
  # /usr/sbin directory would collide with that symlink at compose time. Point
  # sbindir at /usr/bin: the binary lands in /usr/bin/alsactl and every
  # @sbindir@ token resolves to /usr/bin/alsactl.
  #
  # systemdsystemunitdir and udev-rules-dir are pinned to the image layout
  # (/usr/lib/...) rather than left to pkg-config auto-detection.
  #
  # The asound.state dir defaults to /var/lib/alsa (machine-local /var on this
  # image-based OS) which is correct, so it is not overridden. The optional
  # tools are disabled to keep build-deps and footprint minimal.
  conf-local: >-
    --sbindir=%{bindir}
    --with-systemdsystemunitdir=%{indep-libdir}/systemd/system
    --with-udev-rules-dir=%{indep-libdir}/udev/rules.d
    --disable-alsamixer
    --disable-bat
    --disable-alsaloop
    --disable-alsaconf
    --disable-nhlt
    --disable-xmlto
    --disable-rst2man

config:
  install-commands:
  - '%{make-install}'
  # Keep only alsactl. `make install` also runs alsa-utils' install-data-hook,
  # which statically enables the services by dropping relative symlinks into
  # %{indep-libdir}/systemd/system/sound.target.wants/ (sound.target is pulled
  # into every boot by udev's controlC*.device units). The units carry no
  # [Install] section, so a systemd-preset cannot enable them; the static
  # sound.target.wants/ symlinks are the correct, preset-all-safe mechanism.
  # Drop the rest of the suite (amixer, aplay, speaker-test, seq/midi tools,
  # docs, translations, sample sounds) to keep the image lean.
  - find "%{install-root}%{bindir}" -mindepth 1 ! -name alsactl -delete
  - rm -rf "%{install-root}%{mandir}"
  - rm -rf "%{install-root}%{datadir}/locale"
  - rm -rf "%{install-root}%{datadir}/sounds/alsa"
  # The alsatplg topology-compiler plugin builds even with --disable-nhlt;
  # alsatplg itself is pruned above, so its plugin is an orphan.
  - rm -rf "%{install-root}%{libdir}/alsa-topology"
