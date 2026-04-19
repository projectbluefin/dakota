kind: manual

# No external sources - all files are inline.
build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

config:
  install-commands:
  - |
    install -Dm755 /dev/stdin "%{install-root}%{indep-libdir}/bluefin/fix-luks-boot" <<'SCRIPT'
    #!/bin/bash
    # One-time migration for systems installed with older fisherman builds that
    # wrote rd.luks.uuid=<UUID> into BLS entries instead of rd.luks.name=<UUID>=root.
    #
    # bootc >= 1.15.1 strips root=UUID= from generated BLS entries and relies on
    # systemd-gpt-auto-generator (DPS) to find the root. DPS requires the LUKS
    # container to be mapped as /dev/mapper/root. rd.luks.uuid= maps it to
    # /dev/mapper/luks-<UUID> instead, so DPS fails and the system won't boot after
    # bootc switch/upgrade.
    #
    # This script:
    #   1. Updates all BLS entries on the ESP to use rd.luks.name=<UUID>=root
    #      (mirrors what fisherman >= 2026-04-19 does for new installs)
    #   2. Also corrects the LUKS partition GPT type to CA7D7CCB-... (Linux LUKS)
    #      as defense-in-depth (older fisherman used the generic Linux filesystem type)
    #
    # NOTE: Updating BLS entries changes the cmdline measured by TPM2 PCR8.
    # If TPM2 auto-unlock is enrolled, you will need to re-enroll after this runs.
    #
    # References:
    #   https://github.com/projectbluefin/dakota/issues/275
    #   https://github.com/tuna-os/fisherman/pull/18
    set -euo pipefail

    STAMP_FILE="/var/lib/bluefin/.luks-boot-migrated"
    LINUX_LUKS_TYPE="CA7D7CCB-63ED-4C53-861C-1742536059CC"
    LINUX_FS_LOWER="0fc63daf-8483-4772-8e79-3d69d8477de4"

    mkdir -p "$(dirname "$STAMP_FILE")"
    [[ -f "$STAMP_FILE" ]] && exit 0

    # Read the LUKS UUID from the running kernel's cmdline.
    LUKS_UUID=$(grep -oP 'rd\.luks\.uuid=\K[^ ]+' /proc/cmdline | head -1 || true)
    if [[ -z "$LUKS_UUID" ]]; then
        # Not a LUKS system or already using rd.luks.name=; stamp and exit cleanly.
        touch "$STAMP_FILE"
        exit 0
    fi

    # --- Step 1: update BLS entries on the ESP ---

    # Find the EFI System Partition by its well-known GPT type GUID.
    ESP_DEV=$(lsblk -rno NAME,PARTTYPE \
        | awk 'tolower($2)=="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"{print "/dev/"$1}' \
        | head -1)
    if [[ -z "$ESP_DEV" ]]; then
        echo "fix-luks-boot: ESP not found; skipping" >&2
        exit 0
    fi

    # Mount ESP if not already mounted.
    ESP_MOUNT=$(findmnt -rno TARGET "$ESP_DEV" 2>/dev/null | head -1 || true)
    MOUNTED_SELF=0
    if [[ -z "$ESP_MOUNT" ]]; then
        ESP_MOUNT=$(mktemp -d)
        mount "$ESP_DEV" "$ESP_MOUNT"
        MOUNTED_SELF=1
    fi

    cleanup() {
        if [[ $MOUNTED_SELF -eq 1 ]]; then
            umount "$ESP_MOUNT" 2>/dev/null || true
            rmdir "$ESP_MOUNT" 2>/dev/null || true
        fi
    }
    trap cleanup EXIT

    # Replace rd.luks.uuid=<UUID> with rd.luks.name=<UUID>=root in every BLS entry.
    # rd.luks.name=UUID=root is a superset of rd.luks.uuid=UUID: it still unlocks
    # the device AND names the mapper /dev/mapper/root as DPS requires.
    BLS_UPDATED=0
    for CONF in "$ESP_MOUNT"/loader/entries/*.conf; do
        [[ -f "$CONF" ]] || continue
        if grep -q "rd\.luks\.uuid=${LUKS_UUID}" "$CONF"; then
            sed -i "s/rd\.luks\.uuid=${LUKS_UUID}/rd.luks.name=${LUKS_UUID}=root/g" "$CONF"
            echo "fix-luks-boot: patched $(basename "$CONF") -> rd.luks.name=${LUKS_UUID}=root"
            BLS_UPDATED=1
        fi
    done

    # --- Step 2: fix the LUKS partition GPT type (defense-in-depth) ---

    LUKS_DEV=$(blkid -U "$LUKS_UUID" 2>/dev/null || true)
    if [[ -n "$LUKS_DEV" ]]; then
        LUKS_DEV_NAME=$(basename "$LUKS_DEV")
        DISK=$(lsblk -rno PKNAME "$LUKS_DEV" 2>/dev/null | head -1)
        PARTNUM=$(cat "/sys/class/block/$LUKS_DEV_NAME/partition" 2>/dev/null || true)
        if [[ -n "$DISK" && -n "$PARTNUM" ]]; then
            CURRENT_TYPE=$(sfdisk --part-type "/dev/$DISK" "$PARTNUM" 2>/dev/null \
                | tr '[:upper:]' '[:lower:]')
            if [[ "$CURRENT_TYPE" == "$LINUX_FS_LOWER" ]]; then
                # --no-reread --no-tell-kernel: safe on a live root disk; the new type
                # is read from disk on next boot.
                sfdisk --no-reread --no-tell-kernel \
                    --part-type "/dev/$DISK" "$PARTNUM" "$LINUX_LUKS_TYPE"
                echo "fix-luks-boot: updated $LUKS_DEV GPT type to Linux LUKS"
            fi
        fi
    fi

    touch "$STAMP_FILE"
    if [[ $BLS_UPDATED -eq 1 ]]; then
        echo "fix-luks-boot: done; TPM2 PCR8 changes on next boot of patched entries"
    else
        echo "fix-luks-boot: no BLS entries needed patching"
    fi
    SCRIPT

  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system/bluefin-fix-luks-boot.service" <<'SERVICE'
    [Unit]
    Description=Migrate LUKS BLS entries for DPS boot compatibility (bootc >= 1.15.1)
    Documentation=https://github.com/projectbluefin/dakota/issues/275
    ConditionPathExists=!/var/lib/bluefin/.luks-boot-migrated
    After=local-fs.target
    Before=shutdown.target

    [Service]
    Type=oneshot
    ExecStart=/usr/lib/bluefin/fix-luks-boot
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
    SERVICE

  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system-preset/79-bluefin-luks-migration.preset" <<'PRESET'
    enable bluefin-fix-luks-boot.service
    PRESET

  - |
    %{install-extra}
