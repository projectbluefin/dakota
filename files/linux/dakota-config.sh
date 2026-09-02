# Dakota hardware-enablement config deltas, applied after fdsdk-config.sh.
# Source: the 2026-09-01 Fedora config audit (kernel-core 7.1.8-200.fc44),
# per-row reviewed. Buckets: VM-guest storage/net (fixes dakota#1463),
# homelab HBAs, laptop camera/audio/input completion.
# Uses config-utils.sh enable/module so every option lands in
# expected-configs and the post-olddefconfig gate verifies it survived.

# IPU7 lives in drivers/staging/media; these open the menu (they build
# nothing by themselves, staging drivers still need explicit enables).
enable STAGING
enable STAGING_MEDIA

# The power/GPIO half of the Intel IPU camera stack (audit found IPU6 shipped
# without it, so laptop MIPI webcams could not probe). Lives outside the
# audit's bucket regexes, hence listed here explicitly.
module INTEL_SKL_INT3472

enable ATH10K_DEBUGFS
module ATH10K_SDIO
enable FUSION
module FUSION_CTL
enable FUSION_LOGGING
# FUSION_MAX_SGE=128 skipped: int tunable already at upstream default
module FUSION_SAS
module FUSION_SPI
module HID_APPLE
enable HID_BPF
module HID_CHICONY
module HID_GOODIX_SPI
enable HID_HAPTIC
module HID_ITE
module HID_MICROSOFT
module HID_RAZER
module HID_SENSOR_PROX
module HYPERV_VSOCKETS
module MEGARAID_MAILBOX
module MEGARAID_MM
enable MEGARAID_NEWGEN
module MEGARAID_SAS
module MT7663S
module PATA_ACPI
module PATA_ALI
module PATA_ARTOP
module PATA_ATIIXP
module PATA_ATP867X
module PATA_CMD64X
module PATA_HPT366
module PATA_HPT37X
module PATA_HPT3X2N
module PATA_HPT3X3
module PATA_IT8213
module PATA_IT821X
module PATA_JMICRON
module PATA_MARVELL
module PATA_NETCELL
module PATA_NINJA32
module PATA_PCMCIA
module PATA_PDC2027X
module PATA_PDC_OLD
module PATA_SERVERWORKS
module PATA_SIL680
module PATA_SIS
module PATA_VIA
enable RTL8XXXU_UNTESTED
module RTW89_8852AU
module RTW89_8852CU
module SATA_AHCI_PLATFORM
module SATA_MV
module SATA_NV
module SATA_PROMISE
module SATA_SIL24
module SATA_SIL
module SATA_SIS
module SATA_ULI
module SATA_VIA
module SCSI_3W_9XXX
module SCSI_3W_SAS
module SCSI_AACRAID
module SCSI_AIC79XX
module SCSI_AIC7XXX
module SCSI_AM53C974
module SCSI_ARCMSR
module SCSI_BUSLOGIC
module SCSI_ESAS2R
module SCSI_HPSA
module SCSI_ISCI
# SCSI_MPT2SAS_MAX_SGE=128 skipped: int tunable already at upstream default
module SCSI_MPT3SAS
# SCSI_MPT3SAS_MAX_SGE=128 skipped: int tunable already at upstream default
module SCSI_MVSAS
module SCSI_PM8001
module SCSI_SMARTPQI
module SCSI_STEX
module SENSORS_ASUS_ROG_RYUJIN
module SENSORS_GIGABYTE_WATERFORCE
module SENSORS_NZXT_KRAKEN2
module SENSORS_NZXT_KRAKEN3
module SENSORS_NZXT_SMART2
module SENSORS_SURFACE_FAN
module SENSORS_SURFACE_TEMP
module SENSORS_YOGAFAN
module SND_AMD_ASOC_ACP63
module SND_AMD_ASOC_REMBRANDT
module SND_AMD_ASOC_RENOIR
module SND_HDA_CODEC_CM9825
module SND_HDA_CODEC_SENARYTECH
enable SND_HDA_INTEL_HDMI_SILENT_STREAM
module SND_HDA_SCODEC_TAS2781_SPI
enable SND_SEQ_UMP
module SND_SEQ_UMP_CLIENT
module SND_SOC_AMD_ACP_PCI
module SND_SOC_SOF_AMD_ACP70
module SND_SOC_SOF_AMD_RENOIR
module SND_UMP
enable SND_UMP_LEGACY_RAWMIDI
enable SND_USB_AUDIO_MIDI_V2
module TOUCHSCREEN_CHIPONE_ICN8505
enable TOUCHSCREEN_DMI
module TOUCHSCREEN_ELAN
module USB_XEN_HCD
module VBOXSF_FS
module VIDEO_HI846
module VIDEO_HI847
module VIDEO_IMX208
module VIDEO_IMX319
module VIDEO_IMX355
module VIDEO_INTEL_IPU7
module VIDEO_OG01A1B
module VIDEO_OV02C10
module VIDEO_OV02E10
module VIDEO_OV08D10
module VIDEO_OV5675
module VIDEO_OV9734
module VMWARE_VMCI_VSOCKETS
module VMXNET3
enable XEN_GRANT_DMA_OPS
enable XEN_PVH
enable XEN_VIRTIO
module XEN_WDT
