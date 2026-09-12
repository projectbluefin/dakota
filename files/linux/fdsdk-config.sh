#! /bin/bash

# SPDX-FileCopyrightText: Freedesktop-SDK Developers
# SPDX-License-Identifier: MIT

set -eu
# set -x

arch=$1

# Modify the kernel config for additional features

enable RUST

# PinePhone Pro kernel configs
case "$arch" in
    aarch64)
        # Camera Drivers
        module VIDEO_ROCKCHIP_ISP1       # Rockchip Image Signal Processing (ISP) support
        module VIDEO_ROCKCHIP_RGA        # Rockchip Raster 2D Graphic Acceleration Unit
        module VIDEO_ROCKCHIP_VDEC       # Rockchip Video Decoder driver
        module VIDEO_HANTRO              # Hantro VPU (Video Processing Unit) driver
        module VIDEO_OV8858              # OmniVision OV8858 camera sensor support
        module VIDEO_IMX258              # Sony IMX258 camera sensor support
        module VIDEO_DW9714              # DW9714 camera lens voice coil driver

        # Graphics and Display
        enable ROCKCHIP_RGB              # Rockchip RGB support
        module DRM_PANEL_HIMAX_HX8394    # Himax HX8394 display panel support

        # Thermal and Power Management
        module ROCKCHIP_THERMAL          # Thermal sensor support for Rockchip SoCs
        enable ROCKCHIP_MBOX             # Inter-processor communication support for Rockchip SoCs

        # Audio/Video Enhancements
        module V4L2_FLASH_LED_CLASS      # V4L2 flash API support for LED flash

        # Cryptography
        module CRYPTO_DEV_ROCKCHIP       # Rockchip's Cryptographic Engine driver

        # Connectivity and Miscellaneous Hardware
        module PHY_ROCKCHIP_DPHY_RX0     # Rockchip MIPI Synopsys DPHY RX0 driver
        module ROCKCHIP_SARADC           # SAR A/D Converter bindings for Rockchip SoCs

        # Input Devices
        module INPUT_GPIO_VIBRA          # GPIO-based vibrator device support
        module KEYBOARD_PINEPHONE        # PinePhone keyboard case support

        # Backlight and LED
        enable BACKLIGHT_CLASS_DEVICE    # Low-level backlight control
        module LEDS_SGM3140              # SGM3140 LED driver (500mA Buck/Boost Charge Pump)

	# fp5
	module DRM_PANEL_RAYDIUM_RM692E5
	enable REGULATOR_QCOM_PM8008
	enable REGULATOR_QCOM_REFGEN
	module DRM_SIMPLEDRM
	module BACKLIGHT_QCOM_WLED
	enable USB_XHCI_SIDEBAND
	module SND_USB_AUDIO_QMI
	module SND_SOC_USB
	module SND_SOC_QDSP6_USB
	enable SCSI_UFS_QCOM

	# FIXME: Because ARM_SMMU is built-in and will try to probe
	# the clocks, we need to have them built-in. We should try to
	# make ARM_SMMU a module instead.
	enable QCOM_CLK_RPMH
	enable SC_CAMCC_7280
	enable SC_DISPCC_7280
	enable SC_GPUCC_7280
	enable SC_LPASS_CORECC_7280
	enable SC_VIDEOCC_7280
	enable SC_GCC_7280

	enable QCOM_PD_MAPPER
    ;;
esac

# Kernel Config Options
enable DEVTMPFS
enable CGROUPS
enable INOTIFY_USER
enable SIGNALFD
enable TIMERFD
enable EPOLL
enable NET
enable SYSFS
enable PROC_FS
enable FHANDLE

# Enable access to kernel config through /proc/config.gz
enable IKCONFIG
enable IKCONFIG_PROC

# Kernel crypto/hash API
module CRYPTO_ADIANTUM
module CRYPTO_AEGIS128
module CRYPTO_AES
module CRYPTO_ARC4
module CRYPTO_BLOWFISH
module CRYPTO_CAMELLIA
module CRYPTO_CAST5
module CRYPTO_CAST6
module CRYPTO_CBC
module CRYPTO_CHACHA20
module CRYPTO_CHACHA20POLY1305
module CRYPTO_CMAC
module CRYPTO_CRC32
module CRYPTO_CRC32C
module CRYPTO_CTS
module CRYPTO_DEFLATE
module CRYPTO_DES
module CRYPTO_DH
module CRYPTO_ECB
module CRYPTO_ECDSA
module CRYPTO_ECRDSA
module CRYPTO_FCRYPT
module CRYPTO_HMAC
module CRYPTO_LRW
module CRYPTO_LZ4
module CRYPTO_LZ4HC
module CRYPTO_MD4
module CRYPTO_MD5
module CRYPTO_PCBC
module CRYPTO_PCRYPT
module CRYPTO_LIB_POLY1305
module CRYPTO_RMD160
module CRYPTO_SERPENT
module CRYPTO_SHA1
module CRYPTO_SHA256
module CRYPTO_SHA512
module CRYPTO_TWOFISH
module CRYPTO_USER
module CRYPTO_USER_API_AEAD
module CRYPTO_USER_API_RNG
module CRYPTO_WP512
module CRYPTO_XCBC
module CRYPTO_XTS

enable CRYPTO_USER_API_HASH
enable CRYPTO_USER_API_SKCIPHER

case "$arch" in
    x86_64)
        module CRYPTO_AES_NI_INTEL
    ;;
    aarch64)
        module CRYPTO_GHASH_ARM64_CE
        module CRYPTO_AES_ARM64_CE_CCM
        module CRYPTO_AES_ARM64_CE_BLK
        module CRYPTO_AES_ARM64_NEON_BLK
        module CRYPTO_AES_ARM64_BS
    ;;
esac

case "$arch" in
esac

# udev will fail to work with legacy sysfs
remove SYSFS_DEPRECATED

# Boot is very slow with systemd when legacy PTYs are present
remove LEGACY_PTYS

# Legacy hotplug confuses udev
value_str UEVENT_HELPER_PATH ""

# Userspace firmware loading not supported
remove FW_LOADER_USER_HELPER

# Some udev/virtualization requires
enable DMIID

# systemd-creds depends on this
enable DMI_SYSFS
enable FW_CFG_SYSFS

# Support for some SCSI devices serial number retrieval
enable BLK_DEV_BSG

# Required for PrivateNetwork= in service units
enable NET_NS
enable USER_NS

# Required for 9p support
enable NET_9P
enable NET_9P_VIRTIO
enable 9P_FS
enable 9P_FS_POSIX_ACL
enable 9P_FS_SECURITY
enable VIRTIO_PCI

# Strongly Recommended
enable IPV6

# Required for IPv6 support in Tailscale and other VPNs
enable IPV6_MULTIPLE_TABLES

enable AUTOFS_FS
enable TMPFS_XATTR
enable TMPFS_POSIX_ACL
enable EXT4_FS_POSIX_ACL
enable EXT4_FS_SECURITY
enable SECCOMP
enable SECCOMP_FILTER
enable CHECKPOINT_RESTORE

remove IPV6_SIT; module IPV6_SIT

# Required for CPUShares= in resource control unit settings
enable CGROUP_SCHED
enable FAIR_GROUP_SCHED

# Required for CPUQuota= in resource control unit settings
enable CFS_BANDWIDTH

# Required for IPAddressDeny=, IPAddressAllow= in resource control unit settings
enable CGROUP_BPF

# For UEFI systems
enable EFIVAR_FS
enable EFI_PARTITION
if has EFI_GENERIC_STUB; then
    enable EFI_ZBOOT
fi

# RT group scheduling (effectively) makes RT scheduling unavailable for userspace
remove RT_GROUP_SCHED

# Sound with QEMU
module SOUND
module SND
module SND_HDA_GENERIC

# Required for live boot
module SQUASHFS
enable SQUASHFS_ZLIB
module OVERLAY_FS

# Required by snapd
enable SQUASHFS_COMPILE_DECOMP_MULTI_PERCPU
enable SQUASHFS_DECOMP_MULTI_PERCPU
enable SQUASHFS_FILE_DIRECT
enable SQUASHFS_LZ4
enable SQUASHFS_LZO
enable SQUASHFS_XATTR
enable SQUASHFS_XZ
enable SQUASHFS_ZSTD

# erofs is potential replacement of squashfs on GNOME OS
module EROFS_FS
enable EROFS_FS_XATTR
enable EROFS_FS_POSIX_ACL
enable EROFS_FS_SECURITY
enable EROFS_FS_ZIP
enable EROFS_FS_ZIP_LZMA
enable EROFS_FS_ZIP_DEFLATE
enable EROFS_FS_ZIP_ZSTD

# Some useful drivers when running as virtual machine
enable EXCLUSIVE_SYSTEM_RAM
enable STRICT_DEVMEM
enable IO_STRICT_DEVMEM
enable CONFIG_CMA
enable CONTIG_ALLOC

enable VIRTIO_MENU
module VIRTIO_BALLOON
module VIRTIO_INPUT
module SND_VIRTIO
module I2C_VIRTIO
module LIBNVDIMM
module VIRTIO_VFIO_PCI
module VIRTIO_ANCHOR
enable VIRTIO_PMEM
module VIRTIO_NET
module VIRTIO_BLK
module VIRTIO_CONSOLE
enable VIRTIO_PCI_LIB
enable SCSI_VIRTIO
enable VIRTIO_IOMMU
module VDPA
module VIRTIO_VDPA
module VIRTIO_DMA_SHARED_BUFFER

module VIRTIO_MMIO
enable VIRTIO_MMIO_CMDLINE_DEVICES
module CRYPTO_DEV_VIRTIO

case "$arch" in
    aarch64)
        enable ARM64_PMEM
    ;;
esac

case "$arch" in
    aarch64)
        enable ARM_SCMI_PROTOCOL
        enable ARM_SCMI_TRANSPORT_VIRTIO
        enable ARM_SCMI_TRANSPORT_VIRTIO_VERSION1_COMPLIANCE
    ;;
esac

# Input
enable INPUT_EVDEV
enable INPUT_TOUCHSCREEN
enable INPUT_TABLET
module INPUT_MOUSEDEV
case "$arch" in
    x86_64)
        module KEYBOARD_APPLESPI
    ;;
esac
module KEYBOARD_GPIO

# Touchscreens
module TOUCHSCREEN_ATMEL_MXT
module TOUCHSCREEN_DYNAPRO
module TOUCHSCREEN_EETI
module TOUCHSCREEN_ELO
module TOUCHSCREEN_FUJITSU
module TOUCHSCREEN_GOODIX
module TOUCHSCREEN_GUNZE
module TOUCHSCREEN_INEXIO
module TOUCHSCREEN_MTOUCH
module TOUCHSCREEN_PENMOUNT
module TOUCHSCREEN_SURFACE3_SPI
module TOUCHSCREEN_TOUCHIT213
module TOUCHSCREEN_TOUCHRIGHT
module TOUCHSCREEN_TOUCHWIN
module TOUCHSCREEN_TSC2007
module TOUCHSCREEN_TSC_SERIO
module TOUCHSCREEN_USB_COMPOSITE
enable TOUCHSCREEN_USB_E2I
module TOUCHSCREEN_WACOM_W8001
module TOUCHSCREEN_SILEAD

# tablets
module TABLET_SERIAL_WACOM4
module TABLET_USB_ACECAD
module TABLET_USB_AIPTEK
module TABLET_USB_HANWANG
module TABLET_USB_KBTAB
module TABLET_USB_PEGASUS

# needed by spice-vdagent
module VSOCKETS
module VIRTIO_VSOCKETS
module VIRTIO_VSOCKETS_COMMON
module INPUT_UINPUT

# for virtualbox
case "$arch" in
    x86_64)
        enable VIRT_DRIVERS
        module VBOXGUEST
    ;;
esac

# Hyper-V
case "$arch" in
    x86_64|aarch64)
        enable HYPERV
        module PCI_HYPERV
        module HYPERV_BALLOON
        module HYPERV_NET
        if has CONNECTOR; then
            module HYPERV_UTILS
        fi
    ;;
esac

# Xen
case "$arch" in
    x86_64|aarch64)
        enable XEN
        module XEN_SCSI_FRONTEND
    ;;
esac

# VMWare
case "$arch" in
    x86_64)
        module VMWARE_BALLOON
        module VMWARE_VMCI
        module VMWARE_PVSCSI
    ;;
esac

# Android (through Waydroid)
enable ANDROID_BINDER_IPC_RUST

# Needed by some devices
case "$arch" in
    x86_64)
        enable INTEL_TPMI
        enable INTEL_VSEC
        enable X86_INTEL_LPSS
    ;;
esac

# Device Tree and Open Firmware
case "$arch" in
    aarch64)
        enable DTPM
        enable DTPM_CPU
        enable DTPM_DEVFREQ
    ;;
esac

# Wireguard
module WIREGUARD

# Dummy network driver
module DUMMY

# For wireless networks
enable WIRELESS
module CFG80211
enable CFG80211_WEXT
enable MAC80211
enable NETDEVICES
enable WLAN

# Wifi hardware
module IWLWIFI
module IWLMVM
module IWLDVM
module IWLMLD
module ATH9K
module ATH10K
module ATH10K_PCI
module RTW88
enable RTW88_8822BE
enable RTW88_8822CE
module RTW88_8822BS
module RTW88_8822BU
module RTW88_8822CS
module RTW88_8822CU
module RTW88_8723DS
module RTW88_8723CS
module RTW88_8723DU
module RTW88_8821CS
module RTW88_8821CU
module RTW88_8812AU
module RTW88_8814AE
module RTW88_8814AU
module RTW89_8851BE
module RTW89_8851BU
module RTW89_8852BE
module RTW89_8852BU
module RTW89_8852BTE
module RTW89_8852CE
module RTW89_8922AE
enable WLAN_VENDOR_ATH
module AR5523
module ATH10K_USB
module ATH11K
module ATH11K_PCI
module ATH12K
module ATH5K
module ATH6KL
module ATH6KL_SDIO
module ATH6KL_USB
module ATH9K_HTC
module CARL9170
enable CARL9170_LEDS
module WIL6210
enable WIL6210_DEBUGFS
enable WIL6210_ISR_COR
module B43
enable B43_BUSES_BCMA_AND_SSB
enable B43_PHY_G
enable B43_PHY_HT
enable B43_PHY_LP
enable B43_PHY_N
enable B43_SDIO
module B43LEGACY
enable B43LEGACY_DMA_AND_PIO_MODE
module BRCMFMAC
module BRCMSMAC
enable BRCMFMAC_PCIE
enable BRCMFMAC_SDIO
enable BRCMFMAC_USB
module IWL3945
module IWL4965
module P54_COMMON
module P54_PCI
module P54_USB
module MAC80211_HWSIM
module LIBERTAS
enable LIBERTAS_MESH
module LIBERTAS_SDIO
module LIBERTAS_USB
module MWIFIEX
module MWIFIEX_PCIE
module MWIFIEX_SDIO
module MWIFIEX_USB
module MWL8K
module MT7601U
module MT7615E
module MT7663U
module MT76x0E
module MT76x0U
module MT76x2E
module MT76x2U
module MT7603E
module MT7915E
module MT7921E
module MT7921U
module MT7921S
module MT7925E
module MT7925U
module MT7996E
module RT2400PCI
module RT2500PCI
module RT2500USB
module RT2800PCI
enable RT2800PCI_RT3290
enable RT2800PCI_RT33XX
enable RT2800PCI_RT35XX
enable RT2800PCI_RT53XX
module RT2800USB
enable RT2800USB_RT33XX
enable RT2800USB_RT3573
enable RT2800USB_RT35XX
enable RT2800USB_RT53XX
enable RT2800USB_RT55XX
module RT2X00
module RT61PCI
module RT73USB
module RTL8XXXU
module RTW88_8723DE
module RTW88_8821AU
module RTW88_8821CE
module RTW89
module RTW89_8852AE
module RSI_91X
enable RSI_COEX
enable RSI_DEBUGFS
module RSI_USB
module ZD1211RW

# Ethernet hardware
module IGB
module TYPHOON
module VORTEX
module NE2K_PCI
if has PCMCIA; then
    module PCMCIA_PCNET
fi
module ADAPTEC_STARFIRE
module ET131X
module ENA_ETHERNET
module AMD8111_ETH
case "$arch" in
    x86_64|aarch64)
        enable NET_VENDOR_AMD
        module AMD_XGBE
    ;;
esac
module PCNET32
module AQTION
module ALX
module ATL1
module ATL1C
module ATL1E
module ATL2
module B44
module BNX2
module BNX2X
enable BNX2X_SRIOV
module BNXT
enable BNXT_FLOWER_OFFLOAD
enable BNXT_HWMON
enable BNXT_SRIOV
module CNIC
module NET_VENDOR_BROADCOM
module BNA
module CHELSIO_T1
enable CHELSIO_T1_1G
module CHELSIO_T3
module CHELSIO_T4
module CHELSIO_T4VF
module ENIC
enable NET_TULIP
module DE2104X
module DM9102
if has PCMCIA; then
    module PCMCIA_XIRCOM
fi
module TULIP
module ULI526X
module WINBOND_840
module DL2K
module BE2NET
enable BE2NET_BE2
enable BE2NET_BE3
enable BE2NET_LANCER
enable BE2NET_SKYHAWK
module FEALNX
module GVE
module I40E
module I40EVF
module ICE
module IGBVF
module IGC
module IXGBE
enable IXGBE_HWMON
module IXGBEVF
module JME
module SKGE
enable SKGE_GENESIS
enable MLX4_CORE_GEN2
module MLX4_EN
module MLX5_CORE
enable MLX5_CORE_EN
enable MLX5_CORE_IPOIB
enable MLX5_EN_ARFS
enable MLX5_EN_RXNFC
enable MLX5_MPFS
module MLXFW
module KSZ884X_PCI
case "$arch" in
    x86_64)
        enable NET_VENDOR_MICROSOFT
        module MICROSOFT_MANA
    ;;
esac
enable NET_VENDOR_MYRI
module MYRI10GE
module NATSEMI
module NS83820
enable NET_VENDOR_NETRONOME
module NFP
module NETXEN_NIC
module QED
enable QED_SRIOV
module QEDE
enable NET_VENDOR_QLOGIC
module QLA3XXX
module QLCNIC
enable QLCNIC_HWMON
enable QLCNIC_SRIOV
module R6040
module 8139CP
module 8139TOO
enable 8139TOO_8129
enable NET_VENDOR_SOLARFLARE
module SFC_FALCON
module SFC
enable SFC_MCDI_MON
enable SFC_SRIOV
module SC92031
module SIS190
module SIS900
module EPIC100
module SMSC9420
case "$arch" in
    x86_64)
        module DWMAC_INTEL
    ;;
esac
module STMMAC_ETH
module CASSINI
module HAPPYMEAL
module NIU
module SUNGEM
module TEHUTI
module TLAN
module VIA_RHINE
module VIA_VELOCITY
if has PCMCIA; then
    module PCMCIA_XIRC2PS
fi

# Common DRM drivers
enable DRM_SIMPLEDRM
enable SYSFB_SIMPLEFB
module DRM_NOUVEAU
module DRM_RADEON
module DRM_AMDGPU
enable DRM_AMDGPU_SI
enable DRM_AMDGPU_CIK
enable DRM_AMD_DC
case "$arch" in
    x86_64)
        enable DRM_AMD_DC_FP
        enable DRM_AMD_SECURE_DISPLAY
    ;;
esac
case "$arch" in
    x86_64|aarch64)
        enable HSA_AMD
    ;;
esac
enable DRM_AMD_DC_SI
enable DRM_RADEON_USERPTR
enable DRM_AMDGPU_USERPTR
enable DRM_AMD_ACP
case "$arch" in
    x86_64)
        remove DRM_I915; module DRM_I915
        module DRM_GMA500
        module DRM_XE
    ;;
    aarch64)
        module DRM_PANFROST
        module DRM_MSM
        module DRM_PANEL_SAMSUNG_SOFEF00
    ;;
esac

# NPUs
enable DRM_ACCEL
module DRM_ACCEL_QAIC
case "$arch" in
    x86_64)
        module DRM_ACCEL_IVPU
        module DRM_ACCEL_AMDXDNA
        module DRM_ACCEL_HABANALABS
    ;;
    aarch64)
        module DRM_ACCEL_ROCKET
        # ACCEL_ARM_ETHOSU can build on other architectures but not
        # sure if there is any hardware.
        module DRM_ACCEL_ARM_ETHOSU
    ;;
esac

# VFIO
module VFIO
module VFIO_PCI

case "$arch" in
    x86_64)
        enable VFIO_PCI_VGA
    ;;
esac

# Hybrid graphics support
case "$arch" in
    x86_64)
        enable VGA_SWITCHEROO
    ;;
esac

module RC_CORE
module CEC_CORE
enable MEDIA_CEC_RC
enable MEDIA_CEC_SUPPORT

# Needed for HDMI display on Rock 5B
case "$arch" in
    aarch64)
        module PHY_ROCKCHIP_SAMSUNG_HDPTX
        enable ROCKCHIP_DW_HDMI_QP
    ;;
esac

# DRM for virtual machines
module DRM_VIRTIO_GPU
enable DRM_VIRTIO_GPU_KMS
case "$arch" in
    x86_64)
        module DRM_VMWGFX
    ;;
esac
if has HYPERV; then
    module DRM_HYPERV
fi
if has VBOXGUEST; then
    module DRM_VBOXVIDEO
fi

# Common DMA drivers
case "$arch" in
    x86_64)
        module AMD_PTDMA
    ;;
esac

# FUSE
module CUSE
module FUSE_FS
module VIRTIO_FS

# iSCSI
enable SCSI_LOWLEVEL
module ISCSI_TCP
module SCSI_ISCSI_ATTRS

# Device mapper
module DM_CRYPT
module DM_INTEGRITY
enable DM_UEVENT
module DM_RAID
module DM_SNAPSHOT
module DM_VERITY
enable DM_VERITY_VERIFY_ROOTHASH_SIG
enable DM_VERITY_VERIFY_ROOTHASH_SIG_SECONDARY_KEYRING

# Firewire
module FIREWIRE
module FIREWIRE_NET
module FIREWIRE_NOSY
module FIREWIRE_OHCI
module FIREWIRE_SBP2

# GPIO
module GPIO_AMDPT

# USB
enable USB
enable USB_PHY
module USB_ROLE_SWITCH
module USB4
module USB4_NET
case "$arch" in
    x86_64)
        module USB_LGM_PHY
        module USB_ROLES_INTEL_XHCI
    ;;
esac
module TYPEC
module TYPEC_UCSI
module TYPEC_MUX_PI3USB30532
module TYPEC_DP_ALTMODE
module TYPEC_NVIDIA_ALTMODE
module TYPEC_FUSB302
module TYPEC_TCPM
module TYPEC_TPS6598X
module TYPEC_MUX_PTN36502

# USB audio
module SND_USB_AUDIO

# Common USB webcams
enable MEDIA_SUPPORT
enable MEDIA_USB_SUPPORT
enable MEDIA_CAMERA_SUPPORT
module USB_VIDEO_CLASS
module USB_GSPCA
module USB_GSPCA_BENQ
module USB_GSPCA_CONEX
module USB_GSPCA_CPIA1
module USB_GSPCA_DTCS033
module USB_GSPCA_ETOMS
module USB_GSPCA_FINEPIX
module USB_GSPCA_JEILINJ
module USB_GSPCA_JL2005BCD
module USB_GSPCA_KINECT
module USB_GSPCA_KONICA
module USB_GSPCA_MARS
module USB_GSPCA_MR97310A
module USB_GSPCA_NW80X
module USB_GSPCA_OV519
module USB_GSPCA_OV534
module USB_GSPCA_OV534_9
module USB_GSPCA_PAC207
module USB_GSPCA_PAC7302
module USB_GSPCA_PAC7311
module USB_GSPCA_SE401
module USB_GSPCA_SN9C2028
module USB_GSPCA_SN9C20X
module USB_GSPCA_SONIXB
module USB_GSPCA_SONIXJ
module USB_GSPCA_SPCA500
module USB_GSPCA_SPCA501
module USB_GSPCA_SPCA505
module USB_GSPCA_SPCA506
module USB_GSPCA_SPCA508
module USB_GSPCA_SPCA561
module USB_GSPCA_SPCA1528
module USB_GSPCA_SQ905
module USB_GSPCA_SQ905C
module USB_GSPCA_SQ930X
module USB_GSPCA_STK014
module USB_GSPCA_STK1135
module USB_GSPCA_STV0680
module USB_GSPCA_SUNPLUS
module USB_GSPCA_T613
module USB_GSPCA_TOPRO
module USB_GSPCA_TOUPTEK
module USB_GSPCA_TV8532
module USB_GSPCA_VC032X
module USB_GSPCA_VICAM
module USB_GSPCA_XIRLINK_CIT
module USB_GSPCA_ZC3XX
enable MEDIA_PCI_SUPPORT
module USB_PWC
enable USB_PWC_INPUT_EVDEV
if has ACPI && has I2C && has X86; then
    module IPU_BRIDGE
    module VIDEO_IPU3_CIO2
    module VIDEO_INTEL_IPU6
fi

# PHY controllers
enable GENERIC_PHY
enable NETWORK_PHY_TIMESTAMPING
module PHY_CAN_TRANSCEIVER
module ADIN_PHY
module AMD_PHY
module AQUANTIA_PHY
module AT803X_PHY
module BCM54140_PHY
module BCM7XXX_PHY
module BCM87XX_PHY
module BROADCOM_PHY
module CICADA_PHY
module CORTINA_PHY
module DAVICOM_PHY
module DP83822_PHY
module DP83848_PHY
module DP83869_PHY
module ICPLUS_PHY
module INTEL_XWAY_PHY
module LSI_ET1011C_PHY
module LXT_PHY
module MARVELL_10G_PHY
module MARVELL_88Q2XXX_PHY
module MARVELL_88X2222_PHY
module MARVELL_PHY
module MAXLINEAR_GPHY
module MEDIATEK_GE_PHY
module MICREL_PHY
module MICROCHIP_T1S_PHY
module MICROSEMI_PHY
module MOTORCOMM_PHY
module NATIONAL_PHY
module NCN26000_PHY
module NXP_C45_TJA11XX_PHY
module NXP_CBTX_PHY
module PHYLIB
module QSEMI_PHY
module SFP
module STE10XP
module TERANETICS_PHY

# NVME disks
enable NVME_HWMON
module BLK_DEV_NVME
module NVME_FC
module NVME_TCP

# Memory card readers
module MISC_RTSX_PCI
module MMC
module MMC_BLOCK
module MMC_REALTEK_PCI
module SDIO_UART
module MMC_CB710
module MISC_RTSX_USB
module MMC_REALTEK_USB
enable MMC_RICOH_MMC
module MMC_SDHCI
module MMC_SDHCI_ACPI
module MMC_SDHCI_PCI
if has PCMCIA; then
    module MMC_SDRICOH_CS
fi
module MMC_TIFM_SD
module MMC_TOSHIBA_PCI
module MMC_USHC
module MMC_VIA_SDMMC
module MMC_VUB300
if has ISA_DMA_API; then
    module MMC_WBSD
fi

# Needed by some bluetooth drivers
enable SERIAL_DEV_BUS
enable SERIAL_DEV_CTRL_TTYPORT

# Bluetooth
enable BT
enable BT_BREDR
enable BT_LE

module BT_ATH3K
module BT_BNEP
module BT_HCIBCM203X
module BT_HCIBFUSB
module BT_HCIBTUSB
module BT_HIDP
module BT_RFCOMM
if has PCMCIA; then
    module BT_HCIBLUECARD
    module BT_HCIBT3C
    module BT_HCIDTL1
fi
enable BT_HCIBTUSB_AUTOSUSPEND
enable BT_HCIBTUSB_MTK
enable BT_HCIUART_3WIRE
enable BT_HCIUART_AG6XX
enable BT_HCIUART_ATH3K
enable BT_HCIUART_BCM
enable BT_HCIUART_BCSP
enable BT_HCIUART_H4
enable BT_HCIUART_INTEL
enable BT_HCIUART_LL
enable BT_HCIUART_MRVL
enable BT_HCIUART_NOKIA
enable BT_HCIUART_QCA
enable BT_HCIUART_RTL
enable BT_LE_L2CAP_ECRED
enable BT_LEDS
enable BT_MSFTEXT
enable BT_RFCOMM_TTY
module BT_6LOWPAN
enable BT_AOSPEXT
enable BT_BNEP_MC_FILTER
enable BT_BNEP_PROTO_FILTER
module BT_HCIBCM4377
module BT_HCIBPA10X
module BT_HCIBTSDIO
module BT_HCIUART
module BT_HCIVHCI
module BT_INTEL_PCIE
module BT_MRVL
module BT_MRVL_SDIO
module BT_MTKSDIO
module BT_MTKUART
module BT_NXPUART
module BT_VIRTIO

# MIDI
module SND_SEQUENCER
module SND_TIMER
module SND_RAWMIDI

# Sound for HDA
module SND_HDA
remove SND_HDA_INTEL; module SND_HDA_INTEL # module only
enable SND_HDA_RECONFIG
enable SND_HDA_INPUT_BEEP
enable SND_HDA_PATCH_LOADER
enable SND_HDA_CODEC_CA0132_DSP
module SND_HDA_CODEC_ANALOG
module SND_HDA_CODEC_CA0110
module SND_HDA_CODEC_CA0132
module SND_HDA_CODEC_CIRRUS
module SND_HDA_CODEC_CMEDIA
module SND_HDA_CODEC_CONEXANT
module SND_HDA_CODEC_CS8409
module SND_HDA_CODEC_HDMI
module SND_HDA_CODEC_REALTEK
module SND_HDA_CODEC_SI3054
module SND_HDA_CODEC_SIGMATEL
module SND_HDA_CODEC_VIA
module SND_HDA_SCODEC_CS35L41_I2C
module SND_HDA_SCODEC_CS35L41_SPI
module SND_HDA_SCODEC_CS35L56_I2C
module SND_HDA_SCODEC_CS35L56_SPI
module SND_HDA_SCODEC_TAS2781_I2C

# Other sound
enable MEDIA_RADIO_SUPPORT
enable SND_AC97_POWER_SAVE
enable SND_CS46XX_NEW_DSP
enable SND_ES1968_INPUT
enable SND_ES1968_RADIO
enable SND_FIREWIRE
enable SND_FM801_TEA575X_BOOL
enable SND_MAESTRO3_INPUT
enable SND_USB_CAIAQ_INPUT
module SND_AD1889
module SND_ALI5451
module SND_ALOOP
module SND_ALS300
module SND_ATIIXP
module SND_ATIIXP_MODEM
module SND_AU8810
module SND_AU8820
module SND_AU8830
module SND_AZT3328
module SND_BCD2000
module SND_BEBOB
module SND_BT87X
module SND_CA0106
module SND_CMIPCI
module SND_CS4281
module SND_CS46XX
module SND_CTXFI
module SND_DARLA20
module SND_DARLA24
module SND_DICE
module SND_DUMMY
module SND_ECHO3G
module SND_EMU10K1
module SND_EMU10K1X
module SND_ENS1370
module SND_ENS1371
module SND_ES1938
module SND_ES1968
module SND_FIREFACE
module SND_FIREWIRE_DIGI00X
module SND_FIREWIRE_MOTU
module SND_FIREWIRE_TASCAM
module SND_FIREWORKS
module SND_FM801
module SND_GINA20
module SND_GINA24
module SND_HDSP
module SND_HDSPM
module SND_ICE1712
module SND_ICE1724
module SND_INDIGO
module SND_INDIGODJ
module SND_INDIGODJX
module SND_INDIGOIO
module SND_INDIGOIOX
module SND_INTEL8X0
module SND_INTEL8X0M
module SND_ISIGHT
module SND_KORG1212
module SND_LAYLA20
module SND_LAYLA24
module SND_LOLA
module SND_LX6464ES
module SND_MAESTRO3
module SND_MIA
module SND_MIXART
module SND_MONA
module SND_MPU401
module SND_MTPAV
module SND_MTS64
module SND_NM256
module SND_OXFW
module SND_OXYGEN
module SND_PCXHR
module SND_PORTMAN2X4
module SND_RIPTIDE
module SND_RME32
module SND_RME96
module SND_RME9652
module SND_SERIAL_U16550
module SND_SONICVIBES
module SND_TRIDENT
module SND_USB_VARIAX
module SND_VIA82XX
module SND_VIA82XX_MODEM
module SND_VIRMIDI
module SND_VIRTUOSO
module SND_VX222
module SND_YMFPCI
module SOUNDWIRE

module SND_USB_6FIRE
module SND_USB_CAIAQ
module SND_USB_HIFACE
module SND_USB_POD
module SND_USB_PODHD
module SND_USB_TONEPORT
module SND_USB_UA101

if has XEN; then
    module SND_XEN_FRONTEND
fi
if has ISA_DMA_API; then
    module SND_ALS4000
fi
case "$arch" in
    x86_64)
        module SND_ASIHPI
        module SND_PCSP
        module SND_USB_US122L
        module SND_AMD_ASOC_ACP70
        module SND_AMD_ASOC_RENOIR
    ;;
esac
case "$arch" in
    x86_64|ppc64|ppc64le)
        module SND_USB_USX2Y
    ;;
esac

module SND_SOC
module SND_SOC_AMD_ACP
enable SND_SOC_SOF_TOPLEVEL
module SND_SOC_CROS_EC_CODEC
module SND_SOC_CS35L41_I2C
module SND_SOC_CS35L56_I2C
module SND_SOC_CS42L42
module SND_SOC_ES8316
module SND_SOC_HDA
module SND_SOC_MAX98373_SDW
module SND_SOC_NAU8315
module SND_SOC_RT1308_SDW
module SND_SOC_RT5682_SDW
module SND_SOC_RT700_SDW
module SND_SOC_RT711_SDW
module SND_SOC_RT715_SDW
module SND_SOC_SOF_PCI
module SND_SOC_TAS2781_I2C

case "$arch" in
    x86_64)
        enable SND_SOC_INTEL_USER_FRIENDLY_LONG_NAMES
        enable SND_SOC_SOF_HDA_AUDIO_CODEC
        enable SND_SOC_SOF_HDA_LINK
        enable SND_SOC_SOF_INTEL_TOPLEVEL
        module SND_SOC_AMD_ACP_COMMON
        module SND_SOC_AMD_ACP_PCI
        module SND_SOC_AMD_ACP3x
        module SND_SOC_AMD_ACP5x
        module SND_SOC_AMD_ACP6x
        module SND_SOC_AMD_CZ_DA7219MX98357_MACH
        module SND_SOC_AMD_CZ_RT5645_MACH
        module SND_SOC_AMD_LEGACY_MACH
        module SND_SOC_AMD_PS
        module SND_SOC_AMD_PS_MACH
        module SND_SOC_AMD_RENOIR
        module SND_SOC_AMD_RENOIR_MACH
        module SND_SOC_AMD_RV_RT5682_MACH
        module SND_SOC_AMD_SOF_MACH
        module SND_SOC_AMD_VANGOGH_MACH
        module SND_SOC_AMD_YC_MACH
        module SND_SOC_INTEL_AVS
        module SND_SOC_INTEL_AVS_MACH_DA7219
        module SND_SOC_INTEL_AVS_MACH_DMIC
        module SND_SOC_INTEL_AVS_MACH_HDAUDIO
        module SND_SOC_INTEL_AVS_MACH_MAX98373
        module SND_SOC_INTEL_AVS_MACH_MAX98927
        module SND_SOC_INTEL_AVS_MACH_NAU8825
        module SND_SOC_INTEL_AVS_MACH_RT286
        module SND_SOC_INTEL_AVS_MACH_RT5514
        module SND_SOC_INTEL_AVS_MACH_RT5663
        module SND_SOC_INTEL_AVS_MACH_SSM4567
        module SND_SOC_INTEL_BDW_RT5650_MACH
        module SND_SOC_INTEL_BDW_RT5677_MACH
        module SND_SOC_INTEL_BROADWELL_MACH
        module SND_SOC_INTEL_BYT_CHT_CX2072X_MACH
        module SND_SOC_INTEL_BYT_CHT_DA7213_MACH
        module SND_SOC_INTEL_BYT_CHT_ES8316_MACH
        module SND_SOC_INTEL_BYTCR_RT5640_MACH
        module SND_SOC_INTEL_BYTCR_RT5651_MACH
        module SND_SOC_INTEL_CATPT
        module SND_SOC_INTEL_CHT_BSW_MAX98090_TI_MACH
        module SND_SOC_INTEL_CHT_BSW_NAU8824_MACH
        module SND_SOC_INTEL_CHT_BSW_RT5645_MACH
        module SND_SOC_INTEL_CHT_BSW_RT5672_MACH
        module SND_SOC_INTEL_CML_LP_DA7219_MAX98357A_MACH
        module SND_SOC_INTEL_GLK_DA7219_MAX98357A_MACH
        module SND_SOC_INTEL_GLK_RT5682_MAX98357A_MACH
        module SND_SOC_INTEL_HASWELL_MACH
        module SND_SOC_INTEL_SKL_HDA_DSP_GENERIC_MACH
        module SND_SOC_INTEL_SOF_CML_RT1011_RT5682_MACH
        module SND_SOC_INTEL_SOF_CS42L42_MACH
        module SND_SOC_INTEL_SOF_DA7219_MACH
        module SND_SOC_INTEL_SOF_ES8336_MACH
        module SND_SOC_INTEL_SOF_NAU8825_MACH
        module SND_SOC_INTEL_SOF_RT5682_MACH
        module SND_SOC_INTEL_SOF_SSP_AMP_MACH
        module SND_SOC_INTEL_SOUNDWIRE_SOF_MACH
        module SND_SOC_SOF_AMD_REMBRANDT
        module SND_SOC_SOF_AMD_TOPLEVEL
    ;;
esac

# ACPI
enable ACPI_FFH
enable ACPI_PCI_SLOT
enable ACPI_DOCK
enable ACPI_HED
module ACPI_IPMI
module ACPI_PFRUT
module ACPI_TAD

case "$arch" in
    x86_64|aarch64)
        enable ACPI_BGRT
    ;;
esac

if has ARCH_ENABLE_MEMORY_HOTPLUG; then
    enable MEMORY_HOTPLUG
    enable ACPI_HOTPLUG_MEMORY

    if has ARCH_ENABLE_MEMORY_HOTREMOVE; then
        enable MEMORY_HOTREMOVE
        enable ZONE_DEVICE
        enable DEVICE_PRIVATE
        enable HMM_MIRROR

        case "$arch" in
            aarch64|x86_64|riscv*)
                module VIRTIO_MEM
            ;;
        esac
    fi
fi

if has ACPI_NUMA; then
    enable ACPI_HMAT
fi

case "$arch" in
    x86_64|aarch64)
        enable ACPI_FPDT
    ;;
esac

# acpi apei
if has HAVE_ACPI_APEI; then
    enable ACPI_APEI
    enable ACPI_APEI_GHES
    if has ARCH_SUPPORTS_MEMORY_FAILURE; then
        enable ACPI_APEI_MEMORY_FAILURE
    fi
    enable ACPI_APEI_PCIEAER
    module ACPI_APEI_EINJ

    case "$arch" in
        aarch64)
            enable ACPI_APEI_SEA
        ;;
    esac
fi

case "$arch" in
    x86_64)
        module ACPI_EXTLOG
        module ACPI_PROCESSOR_AGGREGATOR
        module ACPI_SBS
    ;;
esac

# acpi pmic
case "$arch" in
    x86_64)
        enable BXT_WC_PMIC_OPREGION
        enable BYTCRC_PMIC_OPREGION
        enable CHTCRC_PMIC_OPREGION
        enable CHT_DC_TI_PMIC_OPREGION
        enable CHT_WC_PMIC_OPREGION
        enable XPOWER_PMIC_OPREGION
    ;;
esac

# HID drivers
module HID_MULTITOUCH
module HID_GENERIC
if has ACPI && has I2C; then
    module I2C_HID_ACPI
    module I2C_HID_OF

    # i2c VIDEO drivers
    module VIDEO_HI556
    module VIDEO_OV01A10
    module VIDEO_OV08X40
    module VIDEO_OV13B10
    module VIDEO_OV2680
    module VIDEO_OV2740
    module VIDEO_OV5670
    module VIDEO_OV5693
    module VIDEO_OV7251
    module VIDEO_OV8856
    module VIDEO_OV8865
fi
enable HIDRAW
module UHID

# CPU support
enable PINCTRL
if has IOMMU_SUPPORT; then
    enable IOMMUFD
fi
case "$arch" in
    x86_64)
        # pinctrl_amd might not work as module if it is loaded to late
        enable PINCTRL_AMD
        enable INTEL_IOMMU
        enable IRQ_REMAP
        enable X86_AMD_PLATFORM_DEVICE
        enable CONFIG_X86_USER_SHADOW_STACK
        enable PINCTRL_INTEL_PLATFORM
        module PINCTRL_ALDERLAKE
        enable PINCTRL_BAYTRAIL
        module PINCTRL_BROXTON
        module PINCTRL_CANNONLAKE
        module PINCTRL_CEDARFORK
        module PINCTRL_CHERRYVIEW
        module PINCTRL_DENVERTON
        module PINCTRL_ELKHARTLAKE
        module PINCTRL_EMMITSBURG
        module PINCTRL_GEMINILAKE
        module PINCTRL_ICELAKE
        module PINCTRL_JASPERLAKE
        module PINCTRL_LAKEFIELD
        module PINCTRL_LEWISBURG
        module PINCTRL_METEORLAKE
        module PINCTRL_METEORPOINT
        module PINCTRL_SUNRISEPOINT
        module PINCTRL_TIGERLAKE
    ;;
esac

if has ARCH_SUPPORTS_MEMORY_FAILURE; then
    enable MEMORY_FAILURE
fi

if has ARCH_SUPPORTS_SHADOW_CALL_STACK; then
    enable SHADOW_CALL_STACK
fi

if has HAVE_IRQ_TIME_ACCOUNTING; then
    enable IRQ_TIME_ACCOUNTING
fi

case "$arch" in
    x86_64|aarch64)
        enable CRYPTO_DEV_CCP
        enable CRYPTO_DEV_CCP_DD
    ;;
esac

case "$arch" in
    x86_64)
        enable CRYPTO_DEV_SP_PSP
        module NTB_AMD
    ;;
esac

# Performance monitoring
case "$arch" in
    x86_64)
        enable PERF_EVENTS_AMD_BRS
        enable PERF_EVENTS_INTEL_CSTATE
        enable PERF_EVENTS_INTEL_RAPL
        enable PERF_EVENTS_INTEL_UNCORE
        module PERF_EVENTS_AMD_POWER
        module PERF_EVENTS_AMD_UNCORE
    ;;
esac

# Enable HW Random
enable HW_RANDOM
enable HW_RANDOM_VIRTIO
case "$arch" in
    x86_64)
        enable HW_RANDOM_AMD
        enable HW_RANDOM_INTEL
    ;;
    aarch64)
        enable HW_RANDOM_ARM_SMCCC_TRNG
    ;;
esac

# NVMEM support
# Needed for USB4 and Thunderbolt
enable MTD
enable NVMEM
module NVMEM_RMEM

# I2C/SMBus
case "$arch" in
    x86_64)
        module I2C_PIIX4
        enable I2C_DESIGNWARE_CORE
        enable I2C_DESIGNWARE_PLATFORM
        enable I2C_DESIGNWARE_BAYTRAIL
        enable I2C_DESIGNWARE_AMDPSP
        module MFD_INTEL_LPSS_PCI
        module MFD_INTEL_LPSS_ACPI
        module I2C_CHT_WC
        module I2C_ISMT
    ;;
esac
module I2C_AMD756
module I2C_AMD8111
module I2C_AMD_MP2
module I2C_DESIGNWARE_PCI
module I2C_DIOLAN_U2C
module I2C_I801
module I2C_ISCH
module I2C_NFORCE2
module I2C_PARPORT
module I2C_PCA_PLATFORM
module I2C_SCMI
module I2C_SIMTEC
module I2C_SIS96X
module I2C_TINY_USB
module I2C_VIA
module I2C_VIAPRO
module I2C_CHARDEV
module I2C_STUB

# Wine/Proton compatibility
module NTSYNC

# RTL Network
module RTL8180
module RTL8187
module RTL8188EE
module RTL8192CE
module RTL8192CU
module RTL8192DE
module RTL8192EE
module RTL8192SE
module RTL8723AE
module RTL8723BE
module RTL8821AE

# USB Network interfaces
module USB_NET_DRIVERS
module USB_USBNET
module USB_NET_CDCETHER
module USB_NET_CDC_SUBSET
module USB_NET_RNDIS_HOST
module USB_RTL8150
module USB_RTL8152
module USB_NET_AQC111
module USB_NET_CDC_EEM
module USB_NET_CDC_MBIM
module USB_NET_CH9200
module USB_NET_CX82310_ETH
module USB_NET_DM9601
module USB_NET_GL620A
module USB_NET_HUAWEI_CDC_NCM
module USB_NET_INT51X1
module USB_NET_KALMIA
module USB_NET_MCS7830
module USB_NET_PLUSB
module USB_NET_QMI_WWAN
module USB_NET_SMSC75XX
module USB_NET_SMSC95XX
enable USB_ALI_M5632
enable USB_AN2720
module USB_CATC
enable USB_EPSON2888
module USB_HSO
module USB_IPHETH
module USB_KAWETH
enable USB_KC2190
module USB_LAN78XX
module USB_NET_SR9700
module USB_PEGASUS
module USB_SIERRA_NET
module USB_VL600

# Parallel ports
module PARPORT

# Serial
if has SERIAL_8250; then
    if has PCMCIA; then
        module SERIAL_8250_CS
    fi
    module SERIAL_8250_DW
fi

# USB Serial
enable USB_SERIAL
module USB_SERIAL_SIMPLE
module USB_SERIAL_FTDI_SIO
module USB_SERIAL_CH341
module USB_ACM
module USB_SERIAL_AIRCABLE
module USB_SERIAL_ARK3116
module USB_SERIAL_BELKIN
module USB_SERIAL_CP210X
module USB_SERIAL_CYBERJACK
module USB_SERIAL_CYPRESS_M8
module USB_SERIAL_DEBUG
module USB_SERIAL_DIGI_ACCELEPORT
module USB_SERIAL_EDGEPORT_TI
module USB_SERIAL_EDGEPORT
module USB_SERIAL_EMPEG
module USB_SERIAL_F8153X
module USB_SERIAL_GARMIN
enable USB_SERIAL_GENERIC
module USB_SERIAL_IPAQ
module USB_SERIAL_IPW
module USB_SERIAL_IR
module USB_SERIAL_IUU
module USB_SERIAL_KEYSPAN_PDA
module USB_SERIAL_KEYSPAN
module USB_SERIAL_KLSI
module USB_SERIAL_KOBIL_SCT
module USB_SERIAL_MCT_U232
module USB_SERIAL_MOS7720
module USB_SERIAL_MOS7840
enable USB_SERIAL_MOS7715_PARPORT
module USB_SERIAL_NAVMAN
module USB_SERIAL_OMNINET
module USB_SERIAL_OPTICON
module USB_SERIAL_OPTION
module USB_SERIAL_OTI6858
module USB_SERIAL_PL2303
module USB_SERIAL_QCAUX
module USB_SERIAL_QT2
module USB_SERIAL_QUALCOMM
module USB_SERIAL_SAFE
module USB_SERIAL_SIERRAWIRELESS
module USB_SERIAL_SPCP8X5
module USB_SERIAL_SSU100
module USB_SERIAL_SYMBOL
module USB_SERIAL_TI
module USB_SERIAL_UPD78F0730
module USB_SERIAL_VISOR
module USB_SERIAL_WHITEHEAT
module USB_SERIAL_XR
module USB_SERIAL_XSENS_MT

# Required by podman
module TUN
enable CGROUP_HUGETLB
enable CGROUP_PIDS
enable CPUSETS
enable MEMCG
enable CGROUP_SCHED
enable BLK_CGROUP

# KVM
case "$arch" in
    x86_64)
        enable PARAVIRT_SPINLOCKS
        enable PARAVIRT_TIME_ACCOUNTING
        module KVM
        module KVM_AMD
        module KVM_INTEL
    ;;
    aarch64)
        module KVM
    ;;
esac
module VHOST_VSOCK
module VHOST_NET
module TARGET_CORE
module VHOST_SCSI
module VDPA_USER
module VHOST_VDPA

# Useful filesystems
for fs in XFS BTRFS EXFAT VFAT F2FS ISO9660 UDF NTFS3; do
    module "${fs}_FS"
done
for fs in BTRFS F2FS NTFS3; do
    enable "${fs}_FS_POSIX_ACL"
done
enable "NTFS3_LZX_XPRESS"
enable "XFS_POSIX_ACL"
enable FS_ENCRYPTION
enable XFS_ONLINE_SCRUB
enable XFS_QUOTA
enable XFS_RT

module NFS_FS
module NFSD

enable FSCACHE

module CIFS
enable CIFS_DEBUG
enable CIFS_DFS_UPCALL
enable CIFS_FSCACHE
enable CIFS_POSIX
enable CIFS_UPCALL
enable CIFS_XATTR

# Needed for FAT filesystems
enable NLS_CODEPAGE_437
enable NLS_ISO8859_1

# Will be needed for composefs
enable FS_VERITY

# FS access notifications
enable FANOTIFY
enable FANOTIFY_ACCESS_PERMISSIONS

# Extcon
module EXTCON
case "$arch" in
    x86_64)
        module EXTCON_AXP288
        module EXTCON_INTEL_CHT_WC
    ;;
esac

# Power management
enable PM
module CHARGER_BQ24190
module BATTERY_BQ27XXX
module BATTERY_MAX17042
case "$arch" in
    x86_64)
        module AXP288_CHARGER
        module AXP288_FUEL_GAUGE
        module BATTERY_SURFACE
        module CHARGER_SURFACE
    ;;
esac

# Regulators
enable REGULATOR
module REGULATOR_FIXED_VOLTAGE
module REGULATOR_VIRTUAL_CONSUMER
module REGULATOR_USERSPACE_CONSUMER
module REGULATOR_88PG86X
module REGULATOR_ACT8865
module REGULATOR_AD5398
module REGULATOR_AW37503
module REGULATOR_AXP20X
module REGULATOR_DA9210
module REGULATOR_DA9211
module REGULATOR_FAN53555
module REGULATOR_GPIO
module REGULATOR_ISL9305
module REGULATOR_ISL6271A
module REGULATOR_LP3971
module REGULATOR_LP3972
module REGULATOR_LP872X
module REGULATOR_LP8755
module REGULATOR_LTC3589
module REGULATOR_LTC3676
module REGULATOR_MAX1586
module REGULATOR_MAX77857
module REGULATOR_MAX8649
module REGULATOR_MAX8660
module REGULATOR_MAX8893
module REGULATOR_MAX8952
module REGULATOR_MAX20086
module REGULATOR_MAX20411
module REGULATOR_MAX77826
module REGULATOR_MP8859
module REGULATOR_MT6311
module REGULATOR_PCA9450
module REGULATOR_PV88060
module REGULATOR_PV88080
module REGULATOR_PV88090
module REGULATOR_PWM
module REGULATOR_RAA215300
module REGULATOR_RT4801
module REGULATOR_RT4803
module REGULATOR_RT5190A
module REGULATOR_RT5739
module REGULATOR_RT5759
module REGULATOR_RT6160
module REGULATOR_RT6190
module REGULATOR_RT6245
module REGULATOR_RTQ2134
module REGULATOR_RTMV20
module REGULATOR_RTQ6752
module REGULATOR_RTQ2208
module REGULATOR_SLG51000
module REGULATOR_TPS51632
module REGULATOR_TPS62360
module REGULATOR_TPS65023
module REGULATOR_TPS6507X
module REGULATOR_TPS65132
module REGULATOR_TPS6524X
module RC_CORE

# PWM
enable PWM
case "$arch" in
    x86_64)
        enable PWM_CRC
        module PWM_LPSS_PLATFORM
    ;;
esac

# RTC
case "$arch" in
    x86_64)
        enable RTC_HCTOSYS
    ;;
esac

# MFD
case "$arch" in
    x86_64)
        enable PMIC_OPREGION
        enable INTEL_SOC_PMIC
        module INTEL_SOC_PMIC_BXTWC
        module INTEL_SOC_PMIC_CHTDC_TI
        enable INTEL_SOC_PMIC_CHTWC
        module LPC_ICH
        module LPC_SCH
        module MFD_INTEL_PMC_BXT
    ;;
    aarch64)
        enable MFD_QCOM_PM8008
    ;;
esac
module MFD_AXP20X_I2C

# RAM error correction
if has HAS_IOMEM && has EDAC_SUPPORT; then
    enable RAS
    module EDAC

    case "$arch" in
        x86_64)
          module EDAC_AMD64
          module EDAC_E752X
          module EDAC_I10NM
          module EDAC_I3000
          module EDAC_I3200
          module EDAC_I5100
          module EDAC_I5400
          module EDAC_I7300
          module EDAC_I7CORE
          module EDAC_I82975X
          module EDAC_IE31200
          module EDAC_IGEN6
          module EDAC_PND2
          module EDAC_SBRIDGE
          module EDAC_SKX
          module EDAC_X38
        ;;
    esac
fi

if has HAS_IOMEM; then
    module IPMI_HANDLER
fi

# PCI
if has HAVE_PCI; then
    enable PCI_IOV
    enable PCI_PRI
    enable PCI_PASID
    enable HOTPLUG_PCI
    enable HOTPLUG_PCI_PCIE
    enable PCIEPORTBUS
    #enable PCIE_PME
    enable PCIE_PTM
    enable NTB
    enable NTB_TRANSPORT
    if has RAS; then
        enable PCIEAER
        module PCIEAER_INJECT
        enable PCIEASPM
        enable PCIE_ECRC
        enable PCIE_DPC
        if has ACPI; then
            enable PCIE_EDR
        fi
    fi
    case "$arch" in
        x86_64)
            module VMD
        ;;
    esac
fi

# RISC-V
case "$arch" in
    riscv*)
        # QEMU
        enable SOC_VIRT

        # Sifive Unmatched
        enable SOC_SIFIVE
        enable SIFIVE_CCACHE
        enable PCIE_FU740
        enable PCIE_MICROSEMI
        enable PCI_SW_SWITCHTEC
        module PWM_SIFIVE
        enable COMMON_CLK_PWM
        enable EDAC_SIFIVE
    ;;
esac

# Initramfs
enable DEVTMPFS
enable BLK_DEV_INITRD
for comp in GZIP BZIP2 LZMA XZ LZO LZ4 ZSTD; do
    enable RD_${comp}
done
remove DEBUG_BLOCK_EXT_DEVT

# Compressed firmware
enable FW_LOADER_COMPRESS
enable FW_LOADER_COMPRESS_ZSTD

# IIO
module IIO
module ADXL372_I2C
module ADXL372_SPI
module BMC150_ACCEL
module DA280
module DA311
module DMARD10
module IIO_ST_ACCEL_3AXIS
module KXCJK1013
module MMA7660
module MMA8452
module MXC4005
module MXC6255
module AD7124
module AD7292
module AD7766
module AD7949
module AXP288_ADC
module MAX1241
module MAX1363
module MCP3911
module TI_ADC128S052
module TI_ADS1015
module AD5770R
module LTC1660
module TI_DAC7311
module ADXRS290
module BMG160
module FXAS21002C
module IIO_ST_GYRO_3AXIS
module MPU3050_I2C
module ADIS16475
module FXOS8700_I2C
module FXOS8700_SPI
module INV_ICM42600_I2C
module INV_ICM42600_SPI
module INV_MPU6050_I2C
module IIO_ST_LSM6DSX
module ACPI_ALS
module ADUX1020
module AL3010
module BH1750
module CM32181
module GP2AP002
module LTR501
module LV0104CS
module MAX44009
module OPT3001
module PA12203001
module RPR0521
module STK3310
module ST_UVIS25
module TSL2772
module VCNL4035
module VEML6030
module VL6180
module ZOPT2201
module AK8975
module BMC150_MAGN_I2C
module IIO_ST_MAGN_3AXIS
module SENSORS_RM3100_I2C
module SENSORS_RM3100_SPI
module ABP060MG
module BMP280
module ICP10100
module MPL115_I2C
module MB1232
module SX9310
module VCNL3020
module VL53L0X_I2C
module LTC2983
module MAX31856
module MAXIM_THERMOCOUPLE
module MLX90614
module MLX90632
module IIO_CROS_EC_ACCEL_LEGACY
module IIO_CROS_EC_BARO
module IIO_CROS_EC_LIGHT_PROX
module IIO_CROS_EC_SENSORS_CORE
module IIO_CROS_EC_SENSORS
module IIO_CROS_EC_SENSORS_LID_ANGLE

# Accessibility
enable ACCESSIBILITY
enable A11Y_BRAILLE_CONSOLE
module SPEAKUP
module SPEAKUP_SYNTH_ACNTSA
module SPEAKUP_SYNTH_APOLLO
module SPEAKUP_SYNTH_AUDPTR
module SPEAKUP_SYNTH_BNS
module SPEAKUP_SYNTH_DECTLK
module SPEAKUP_SYNTH_LTLK
module SPEAKUP_SYNTH_SOFT
module SPEAKUP_SYNTH_SPKOUT
module SPEAKUP_SYNTH_TXPRT

# Joysticks
enable INPUT_JOYSTICK
# Joydev API
module INPUT_JOYDEV

# Joysticks (Xbox)
module JOYSTICK_XPAD
enable JOYSTICK_XPAD_FF
enable JOYSTICK_XPAD_LEDS

# Logitech game controllers
module HID_LOGITECH
module HID_LOGITECH_DJ
module HID_LOGITECH_HIDPP
enable LOGITECH_FF
enable LOGIRUMBLEPAD2_FF
enable LOGIG940_FF
enable LOGIWHEELS_FF

# Steam controller
module HID_STEAM

# Joydev API
module INPUT_JOYDEV

# Other joysticks
module JOYSTICK_A3D
module JOYSTICK_ADI
module JOYSTICK_ANALOG
module JOYSTICK_COBRA
module JOYSTICK_DB9
module JOYSTICK_GAMECON
module JOYSTICK_GF2K
module JOYSTICK_GRIP_MP
module JOYSTICK_GRIP
module JOYSTICK_GUILLEMOT
module JOYSTICK_IFORCE_232
module JOYSTICK_IFORCE_USB
module JOYSTICK_IFORCE
module JOYSTICK_INTERACT
module JOYSTICK_JOYDUMP
module JOYSTICK_MAGELLAN
module JOYSTICK_PXRC
module JOYSTICK_SIDEWINDER
module JOYSTICK_SPACEBALL
module JOYSTICK_SPACEORB
module JOYSTICK_STINGER
module JOYSTICK_TMDC
module JOYSTICK_TURBOGRAFX
module JOYSTICK_TWIDJOY
module JOYSTICK_WALKERA0701
module JOYSTICK_WARRIOR
module JOYSTICK_ZHENHUA

# gameport
module GAMEPORT_EMU10K1
module GAMEPORT_FM801

# Other human interfaces
module HID_ACCUTOUCH
module HID_ACRUX
enable HID_ACRUX_FF
module HID_ALPS
module HID_APPLEIR
module HID_ASUS
module HID_AUREAL
enable HID_BATTERY_STRENGTH
module HID_BETOP_FF
module HID_BIGBEN_FF
module HID_CMEDIA
module HID_CORSAIR
module HID_COUGAR
module HID_CP2112
module HID_CREATIVE_SB0540
module HID_DRAGONRISE
enable DRAGONRISE_FF
module HID_ELAN
module HID_ELECOM
module HID_ELO
module HID_EMS_FF
module HID_FT260
module HID_GEMBIRD
module HID_GFRM
module HID_GLORIOUS
module HID_GREENASIA
enable GREENASIA_FF
module HID_GT683R
module HID_HOLTEK
enable HOLTEK_FF
if has HYPERV; then
    module HID_HYPERV_MOUSE
fi
module HID_ICADE
module HID_JABRA
module HID_KEYTOUCH
module HID_KYE
module HID_LCPOWER
module HID_LED
module HID_LENOVO
module HID_MACALLY
module HID_MAGICMOUSE
module HID_MALTRON
module HID_MAYFLASH
module HID_MCP2221
module HID_NINTENDO
enable NINTENDO_FF
module HID_NTI
module HID_ORTEK
module HID_PENMOUNT
module HID_PICOLCD
module HID_PLANTRONICS
module HID_PLAYSTATION
enable PLAYSTATION_FF
module HID_PRIMAX
module HID_PRODIKEYS
module HID_RETRODE
module HID_RMI
# Touchscreen for OnePlus 6
module RMI4_I2C
enable RMI4_F55
module HID_ROCCAT
module HID_SAITEK
module HID_SEMITEK
module HID_SENSOR_ACCEL_3D
module HID_SENSOR_ALS
module HID_SENSOR_DEVICE_ROTATION
module HID_SENSOR_GYRO_3D
module HID_SENSOR_HUB
module HID_SENSOR_INCLINOMETER_3D
module HID_SENSOR_MAGNETOMETER_3D
module HID_SENSOR_TEMP
module HID_SMARTJOYPLUS
enable SMARTJOYPLUS_FF
module HID_SPEEDLINK
module HID_STEELSERIES
module HID_THINGM
module HID_THRUSTMASTER
enable THRUSTMASTER_FF
module HID_TIVO
module HID_TWINHAN
module HID_U2FZERO
module HID_UCLOGIC
module HID_UDRAW_PS3
module HID_VIEWSONIC
module HID_VIVALDI
module HID_WACOM
module HID_WALTOP
module HID_WIIMOTE
module HID_XINMO
module HID_ZEROPLUS
enable ZEROPLUS_FF
module HID_ZYDACRON
module HID_SONY
enable SONY_FF
case "$arch" in
    x86_64)
        module INTEL_ISH_HID
        module SURFACE_HID
        module SURFACE_KBD
    ;;
esac
case "$arch" in
    x86_64)
        module AMD_SFH_HID
    ;;
esac

# Mice
module MOUSE_APPLETOUCH
module MOUSE_BCM5974
module MOUSE_CYAPA
module MOUSE_ELAN_I2C
enable MOUSE_ELAN_I2C_I2C
enable MOUSE_ELAN_I2C_SMBUS
enable MOUSE_PS2_ELANTECH
enable MOUSE_PS2_SENTELIC
case "$arch" in
    x86_64)
        enable MOUSE_PS2_VMMOUSE
    ;;
esac
module MOUSE_SERIAL
module MOUSE_SYNAPTICS_I2C
module MOUSE_SYNAPTICS_USB
module MOUSE_VSXXXAA

# Make sure to enable virtual terminals in DRM
enable FB
enable FB_EFI
enable DRM_FBDEV_EMULATION
enable FRAMEBUFFER_CONSOLE

# TODO: remove NETFILTER_XTABLES_LEGACY
enable NETFILTER_XTABLES_LEGACY

# Network
module BRIDGE
module BRIDGE_NETFILTER
enable BRIDGE_VLAN_FILTERING
enable NETFILTER
enable IP_NF_IPTABLES
enable IP_NF_FILTER
enable IP_NF_TARGET_REJECT
module IP_NF_TARGET_MASQUERADE
enable IP_NF_MANGLE
enable NF_CONNTRACK
module NF_CONNTRACK_BRIDGE
enable NF_NAT
module IP_NF_NAT
enable IP6_NF_IPTABLES
enable IP6_NF_MATCH_IPV6HEADER
enable IP6_NF_FILTER
enable IP6_NF_TARGET_REJECT
enable IP6_NF_MANGLE
module IP_NF_RAW
module IP6_NF_RAW
module IP6_NF_NAT
enable NETFILTER_ADVANCED
module VETH
module BLK_DEV_NBD
module 6LOWPAN
module IPVLAN
module VLAN_8021Q

# Those two modules are required by multipass
module NETFILTER_XT_MATCH_COMMENT
module NETFILTER_XT_TARGET_CHECKSUM

# Some more netfilter/nft
module IP_NF_ARPFILTER
module IP_NF_ARP_MANGLE
module IP_NF_MATCH_AH
module IP_NF_MATCH_ECN
module IP_NF_MATCH_RPFILTER
module IP_NF_MATCH_TTL
module IP_NF_SECURITY
module IP_NF_TARGET_ECN
module IP_NF_TARGET_NETMAP
module IP_NF_TARGET_REDIRECT
module IP_NF_TARGET_SYNPROXY
module IP_NF_TARGET_TTL
module NF_NAT_SNMP_BASIC
module NF_SOCKET_IPV4
enable NF_TABLES_ARP
enable NF_TABLES_IPV4
module NF_TABLES_BRIDGE
module NFT_DUP_IPV4
module NFT_FIB_IPV4
module NF_TPROXY_IPV4
module NF_TPROXY_IPV4
module IP6_NF_MATCH_AH
module IP6_NF_MATCH_EUI64
module IP6_NF_MATCH_FRAG
module IP6_NF_MATCH_HL
module IP6_NF_MATCH_MH
module IP6_NF_MATCH_OPTS
module IP6_NF_MATCH_RPFILTER
module IP6_NF_MATCH_RT
module IP6_NF_MATCH_SRH
module IP6_NF_SECURITY
module IP6_NF_TARGET_HL
module IP6_NF_TARGET_MASQUERADE
module IP6_NF_TARGET_NPT
module IP6_NF_TARGET_SYNPROXY
module NF_SOCKET_IPV6
enable NF_TABLES_IPV6
module NFT_DUP_IPV6
module NFT_FIB_IPV6
module NF_TPROXY_IPV6
module IP_SET
module IP_SET_BITMAP_IP
module IP_SET_BITMAP_IPMAC
module IP_SET_BITMAP_PORT
module IP_SET_HASH_IP
module IP_SET_HASH_IPMAC
module IP_SET_HASH_IPMARK
module IP_SET_HASH_IPPORT
module IP_SET_HASH_IPPORTIP
module IP_SET_HASH_IPPORTNET
module IP_SET_HASH_MAC
module IP_SET_HASH_NET
module IP_SET_HASH_NETIFACE
module IP_SET_HASH_NETNET
module IP_SET_HASH_NETPORT
module IP_SET_HASH_NETPORTNET
module IP_SET_LIST_SET
module IP_VS
module NETFILTER_NETLINK_ACCT
module NETFILTER_NETLINK_OSF
module NETFILTER_NETLINK_QUEUE
module NETFILTER_XT_MATCH_BPF
module NETFILTER_XT_MATCH_CGROUP
module NETFILTER_XT_MATCH_CLUSTER
module NETFILTER_XT_MATCH_CONNBYTES
module NETFILTER_XT_MATCH_CONNLABEL
module NETFILTER_XT_MATCH_CONNLIMIT
module NETFILTER_XT_MATCH_CONNMARK
module NETFILTER_XT_MATCH_CPU
module NETFILTER_XT_MATCH_DCCP
module NETFILTER_XT_MATCH_DEVGROUP
module NETFILTER_XT_MATCH_DSCP
module NETFILTER_XT_MATCH_ECN
module NETFILTER_XT_MATCH_ESP
module NETFILTER_XT_MATCH_HASHLIMIT
module NETFILTER_XT_MATCH_HELPER
module NETFILTER_XT_MATCH_HL
module NETFILTER_XT_MATCH_IPCOMP
module NETFILTER_XT_MATCH_IPRANGE
module NETFILTER_XT_MATCH_IPVS
module NETFILTER_XT_MATCH_L2TP
module NETFILTER_XT_MATCH_LENGTH
module NETFILTER_XT_MATCH_LIMIT
module NETFILTER_XT_MATCH_MAC
module NETFILTER_XT_MATCH_MARK
module NETFILTER_XT_MATCH_MULTIPORT
module NETFILTER_XT_MATCH_NFACCT
module NETFILTER_XT_MATCH_OSF
module NETFILTER_XT_MATCH_OWNER
module NETFILTER_XT_MATCH_PHYSDEV
module NETFILTER_XT_MATCH_PKTTYPE
module NETFILTER_XT_MATCH_QUOTA
module NETFILTER_XT_MATCH_RATEEST
module NETFILTER_XT_MATCH_REALM
module NETFILTER_XT_MATCH_RECENT
module NETFILTER_XT_MATCH_SCTP
module NETFILTER_XT_MATCH_SOCKET
module NETFILTER_XT_MATCH_STATISTIC
module NETFILTER_XT_MATCH_STRING
module NETFILTER_XT_MATCH_TCPMSS
module NETFILTER_XT_MATCH_TIME
module NETFILTER_XT_MATCH_U32
module NETFILTER_XT_SET
module NETFILTER_XT_TARGET_AUDIT
module NETFILTER_XT_TARGET_CLASSIFY
module NETFILTER_XT_TARGET_CONNMARK
module NETFILTER_XT_TARGET_CT
module NETFILTER_XT_TARGET_DSCP
module NETFILTER_XT_TARGET_HMARK
module NETFILTER_XT_TARGET_IDLETIMER
module NETFILTER_XT_TARGET_LED
module NETFILTER_XT_TARGET_MARK
module NETFILTER_XT_TARGET_NETMAP
module NETFILTER_XT_TARGET_NFQUEUE
module NETFILTER_XT_TARGET_RATEEST
module NETFILTER_XT_TARGET_REDIRECT
module NETFILTER_XT_TARGET_TCPOPTSTRIP
module NETFILTER_XT_TARGET_TEE
module NETFILTER_XT_TARGET_TPROXY
module NETFILTER_XT_TARGET_TRACE
module NF_CONNTRACK_AMANDA
enable NF_CONNTRACK_EVENTS
module NF_CONNTRACK_H323
enable NF_CONNTRACK_MARK
module NF_CONNTRACK_NETBIOS_NS
module NF_CONNTRACK_PPTP
enable NF_CONNTRACK_PROCFS
module NF_CONNTRACK_SANE
module NF_CONNTRACK_SNMP
module NF_CONNTRACK_TFTP
enable NF_CONNTRACK_TIMEOUT
enable NF_CONNTRACK_TIMESTAMP
enable NF_CONNTRACK_ZONES
module NF_CT_NETLINK_TIMEOUT
module NF_DUP_NETDEV
module NF_FLOW_TABLE
module NF_FLOW_TABLE_INET
module NF_TABLES
enable NF_TABLES_INET
enable NF_TABLES_NETDEV
module NFT_COMPAT
module NFT_CONNLIMIT
module NFT_CT
module NFT_DUP_NETDEV
module NFT_FIB_INET
module NFT_FIB_NETDEV
module NFT_FLOW_OFFLOAD
module NFT_FWD_NETDEV
module NFT_HASH
module NFT_LIMIT
module NFT_LOG
module NFT_MASQ
module NFT_NAT
module NFT_NUMGEN
module NFT_QUEUE
module NFT_QUOTA
module NFT_REDIR
module NFT_REJECT
module NFT_SOCKET
module NFT_SYNPROXY
module NFT_TPROXY
module NFT_TUNNEL

# Security modules
enable SECURITY_SELINUX
enable SECURITY_APPARMOR
enable SECURITY_LANDLOCK
enable AUDIT

# SPI
if has HAS_IOMEM; then
    enable PCI
    enable SPI_MASTER
    enable SPI_MEM
    enable SPI
    module SPI_AMD
fi

# TPM
enable TCG_TPM
enable TCG_CRB
enable TCG_TIS
if has SPI; then
    enable TCG_TIS_SPI
fi

# BPF
enable FTRACE
enable FUNCTION_TRACER
if has HAVE_KPROBES; then
    enable KPROBES
fi
if has ARCH_SUPPORTS_UPROBES; then
    enable UPROBE_EVENTS
fi
enable BPF_SYSCALL
enable CGROUP_BPF
if has HAVE_CBPF_JIT || has HAVE_EBPF_JIT; then
    enable BPF_JIT
    enable BPF_LSM
fi

remove DEBUG_INFO_SPLIT
remove DEBUG_INFO_REDUCED
enable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
enable DEBUG_INFO_BTF

# Ramdisk
module BLK_DEV_RAM

# ZSWAP
enable ZSWAP

# ZRAM
module ZRAM
enable ZRAM_WRITEBACK
enable ZRAM_MEMORY_TRACKING
enable ZRAM_MULTI_COMP
enable ZRAM_BACKEND_ZSTD
enable ZRAM_DEF_COMP_ZSTD
module CRYPTO_ZSTD

# Secure boot
enable SYSTEM_BLACKLIST_KEYRING
enable SYSTEM_TRUSTED_KEYRING
enable INTEGRITY_PLATFORM_KEYRING
enable INTEGRITY_SIGNATURE
enable INTEGRITY_ASYMMETRIC_KEYS
enable SECONDARY_TRUSTED_KEYRING
if has EFI; then
    enable INTEGRITY_MACHINE_KEYRING
    enable LOAD_UEFI_KEYS
fi
enable IMA
enable IMA_APPRAISE
enable IMA_SECURE_AND_OR_TRUSTED_BOOT
enable IMA_ARCH_POLICY

# Module signing
# /keys/linux-module-cert.crt is provided by downstream
if [ -f /keys/linux-module-cert.crt ]; then
    enable MODULE_SIG
    value_str SYSTEM_TRUSTED_KEYS /keys/linux-module-cert.crt
    # Building with MODULE_SIG_KEY is not reproducible
    value_str MODULE_SIG_KEY ""
    # We sign modules separately
    remove MODULE_SIG_ALL
    # Instead we use lsm=lockdown on command line
    remove MODULE_SIG_FORCE

    # sha512 signing only
    remove MODULE_SIG_SHA1
    remove MODULE_SIG_SHA224
    remove MODULE_SIG_SHA256
    remove MODULE_SIG_SHA384
    enable MODULE_SIG_SHA512
    value_str MODULE_SIG_HASH "sha512"

    enable SECURITY_LOCKDOWN_LSM
    enable SECURITY_LOCKDOWN_LSM_EARLY
else
    remove MODULE_SIG
fi

# systemd-oom
enable PSI

# Hardware monitors
case "$arch" in
    x86_64)
        module SENSORS_ABITUGURU
        module SENSORS_ABITUGURU3
        module SENSORS_APPLESMC
        module SENSORS_ASB100
        module SENSORS_ASUS_EC
        module SENSORS_ATK0110
        module SENSORS_CORETEMP
        module SENSORS_DELL_SMM
        module SENSORS_FAM15H_POWER
        module SENSORS_FSCHMD
        module SENSORS_I5500
        module SENSORS_K10TEMP
        module SENSORS_K8TEMP
        module SENSORS_NCT6683
        module SENSORS_NCT6775
        module SENSORS_NCT7802
        module SENSORS_NCT7904
        module SENSORS_VIA_CPUTEMP
    ;;
esac

module SENSORS_ACPI_POWER
module SENSORS_AD7414
module SENSORS_AD7418
module SENSORS_ADCXX
module SENSORS_ADM1025
module SENSORS_ADM1026
module SENSORS_ADM1029
module SENSORS_ADM1031
module SENSORS_ADM9240
module SENSORS_ADS7828
module SENSORS_ADS7871
module SENSORS_ADT7411
module SENSORS_ADT7462
module SENSORS_ADT7470
module SENSORS_ADT7475
module SENSORS_AMC6821
module SENSORS_AQUACOMPUTER_D5NEXT
module SENSORS_ASC7621
module SENSORS_ATXP1
module SENSORS_CORSAIR_CPRO
module SENSORS_CORSAIR_PSU
module SENSORS_DME1737
module SENSORS_DRIVETEMP
module SENSORS_DS1621
module SENSORS_DS620
module SENSORS_EMC1403
module SENSORS_EMC6W201
module SENSORS_F71805F
module SENSORS_F71882FG
module SENSORS_F75375S
module SENSORS_FTSTEUTATES
module SENSORS_G760A
module SENSORS_GL518SM
module SENSORS_GL520SM
module SENSORS_I5K_AMB
module SENSORS_IBMAEM
module SENSORS_IBMPEX
module SENSORS_IT87
module SENSORS_JC42
module SENSORS_LINEAGE
module SENSORS_LM63
module SENSORS_LM70
module SENSORS_LM73
module SENSORS_LM75
module SENSORS_LM77
module SENSORS_LM78
module SENSORS_LM80
module SENSORS_LM83
module SENSORS_LM85
module SENSORS_LM87
module SENSORS_LM90
module SENSORS_LM92
module SENSORS_LM93
module SENSORS_LM95241
module SENSORS_LM95245
module SENSORS_LTC4151
module SENSORS_LTC4215
module SENSORS_LTC4245
module SENSORS_LTC4261
module SENSORS_MAX1111
module SENSORS_MAX16065
module SENSORS_MAX1619
module SENSORS_MAX1668
module SENSORS_MAX6639
module SENSORS_MAX6650
module SENSORS_NPCM7XX
module SENSORS_NTC_THERMISTOR
module SENSORS_PC87360
module SENSORS_PC87427
module SENSORS_PCF8591
module SENSORS_SCH5627
module SENSORS_SCH5636
module SENSORS_SHT21
module SENSORS_SHT3x
module SENSORS_SIS5595
module SENSORS_SMSC47B397
module SENSORS_SMSC47M1
module SENSORS_SMSC47M192
module SENSORS_SPD5118
module SENSORS_THMC50
module SENSORS_TMP102
module SENSORS_TMP401
module SENSORS_TMP421
module SENSORS_VIA686A
module SENSORS_VT1211
module SENSORS_VT8231
module SENSORS_W83627EHF
module SENSORS_W83627HF
module SENSORS_W83773G
module SENSORS_W83781D
module SENSORS_W83791D
module SENSORS_W83792D
module SENSORS_W83793
module SENSORS_W83795
module SENSORS_W83L785TS
module SENSORS_W83L786NG

# LEDS
enable LED_TRIGGER_PHY
enable LEDS_BRIGHTNESS_HW_CHANGED
enable LEDS_TRIGGERS
enable NEW_LEDS
module LEDS_CLASS
module LEDS_CLASS_FLASH
module LEDS_CLASS_MULTICOLOR
module LEDS_LP3944
module LEDS_LT3593
module LEDS_REGULATOR

enable LEDS_TRIGGER_DISK
enable LEDS_TRIGGER_PANIC
module LEDS_TRIGGER_ACTIVITY
module LEDS_TRIGGER_BACKLIGHT
module LEDS_TRIGGER_CAMERA
module LEDS_TRIGGER_DEFAULT_ON
module LEDS_TRIGGER_HEARTBEAT
module LEDS_TRIGGER_NETDEV
module LEDS_TRIGGER_ONESHOT
module LEDS_TRIGGER_PATTERN
module LEDS_TRIGGER_TIMER
module LEDS_TRIGGER_TRANSIENT

case "$arch" in
    x86_64)
        module LEDS_APU
        module LEDS_INTEL_SS4200
    ;;
    aarch64)
	module LEDS_QCOM_FLASH
    ;;
esac

enable CPU_FREQ
if has GENERIC_ARCH_TOPOLOGY; then
    module CPUFREQ_VIRT
fi

# cpufreq
case "$arch" in
    x86_64)
        enable CPU_FREQ_STAT
        enable X86_AMD_PSTATE
        enable CPU_FREQ_DEFAULT_GOV_SCHEDUTIL
        module CPU_FREQ_GOV_CONSERVATIVE
        module CPU_FREQ_GOV_PERFORMANCE
        module CPU_FREQ_GOV_POWERSAVE
        module X86_AMD_FREQ_SENSITIVITY
        module X86_AMD_PSTATE_UT
        module X86_P4_CLOCKMOD
        module X86_PCC_CPUFREQ
        module X86_POWERNOW_K8
    ;;
    aarch64)
        enable ACPI_CPPC_CPUFREQ_FIE
        enable ARM_PSCI_CPUIDLE_DOMAIN
        module CPUFREQ_DT
        module ACPI_CPPC_CPUFREQ
        module ARM_SCPI_CPUFREQ
    ;;
esac

# Scheduler
if has ARCH_HAS_PREEMPT_LAZY; then
    enable PREEMPT_LAZY
fi

# Platforms
case "$arch" in
    aarch64|x86_64)
        # Chrome Platform
        enable CHROME_PLATFORMS
        module CHARGER_CROS_USBPD
        module CHROMEOS_ACPI
        module CHROMEOS_PRIVACY_SCREEN
        module CHROMEOS_TBMC
        module CROS_EC
        module CROS_EC_I2C
        module CROS_EC_SPI
        module CROS_EC_UART
        module CROS_EC_UART
        module CROS_HPS_I2C
        module CROS_HPS_I2C
        module CROS_KBD_LED_BACKLIGHT
        module CROS_USBPD_LOGGER

        # Mellanox Platform
        enable MELLANOX_PLATFORM
        module MLXREG_HOTPLUG
        module MLXREG_IO
        module MLXREG_LC
        module NVSW_SN2201
    ;;
esac

case "$arch" in
    x86_64)
        enable MLX_PLATFORM
        module CHROMEOS_LAPTOP
        module CHROMEOS_PSTORE
        module CROS_EC_LPC
        module SURFACE_AGGREGATOR
        module SURFACE_AGGREGATOR_CDEV
        module SURFACE_AGGREGATOR_HUB
        module SURFACE_AGGREGATOR_TABLET_SWITCH
        module SURFACE_3_POWER_OPREGION
        module SURFACE_ACPI_NOTIFY
        module SURFACE_AGGREGATOR_REGISTRY
        module SURFACE_DTX
        module SURFACE_GPE
        module SURFACE_HOTPLUG
        module SURFACE_PLATFORM_PROFILE
        module SURFACE_PRO3_BUTTON
        module ACERHDF
        module ACER_WIRELESS
        module ACPI_TOSHIBA
        module AMD_PMC
        module TEE
        module AMDTEE
        module AMD_PMF
        module AMILO_RFKILL
        module APPLE_GMUX
        module ASUS_LAPTOP
        module ASUS_WIRELESS
        module COMPAL_LAPTOP
        module FUJITSU_LAPTOP
        module FUJITSU_TABLET
        module GPD_POCKET_FAN
        module HP_ACCEL
        module IDEAPAD_LAPTOP
        module INTEL_ATOMISP2_PM
        module INTEL_CHTWC_INT33FE
        module INTEL_HID_EVENT
        module INTEL_INT0002_VGPIO
        module INTEL_OAKTRAIL
        module INTEL_RST
        module INTEL_SMARTCONNECT
        enable INTEL_TURBO_MAX_3
        module INTEL_VBTN
        module INTEL_IPS
        module INTEL_PMT_TELEMETRY
        module INTEL_PMC_CORE
        module LG_LAPTOP
        module LENOVO_YMC
        module MSI_LAPTOP
        module MSI_EC
        module PANASONIC_LAPTOP
        module PCENGINES_APU2
        module SAMSUNG_LAPTOP
        module SAMSUNG_Q10
        module SENSORS_HDAPS
        module SERIAL_MULTI_INSTANTIATE
        module SYSTEM76_ACPI
        module SONY_LAPTOP
        enable SONYPI_COMPAT
        module THINKPAD_ACPI
        enable THINKPAD_ACPI_ALSA_SUPPORT
        enable THINKPAD_ACPI_HOTKEY_POLL
        enable THINKPAD_ACPI_VIDEO
        enable THINKPAD_LMI
        module TOPSTAR_LAPTOP
        module TOSHIBA_BT_RFKILL
        module TOSHIBA_HAPS
        module TOSHIBA_WMI
        module WIRELESS_HOTKEY
        module YOGABOOK
        module ACPI_WMI
        module ACER_WMI
        module GIGABYTE_WMI
        enable X86_PLATFORM_DRIVERS_DELL
        enable X86_PLATFORM_DRIVERS_HP
        module ALIENWARE_WMI
        module ASUS_NB_WMI
        module ASUS_ARMOURY
        module ASUS_WMI
        module ASUS_TF103C_DOCK
        enable DELL_SMBIOS_WMI
        module DELL_WMI_AIO
        module DELL_WMI_LED
        module DELL_WMI
        module EEEPC_WMI
        module HP_WMI
        module HUAWEI_WMI
        module INTEL_WMI_THUNDERBOLT
        module MSI_WMI
        module NVIDIA_WMI_EC_BACKLIGHT
        module SENSORS_ASUS_WMI
        module SENSORS_HP_WMI
        module SURFACE3_WMI
        module X86_ANDROID_TABLETS

        # hdmi audio with DRM_I915
        module HDMI_LPE_AUDIO
    ;;
esac

# power
enable ENERGY_MODEL
enable POWER_RESET
enable POWER_RESET_RESTART
enable POWER_SUPPLY
enable POWER_SUPPLY_HWMON

# power/supply
module BATTERY_CW2015
module BATTERY_RT5033
module BATTERY_UG3105
module CHARGER_BD99954
module CHARGER_BQ2515X
module CHARGER_BQ256XX
module CHARGER_BQ25890
module CHARGER_LT3651
module CHARGER_LTC4162L
module CHARGER_MAX77976
module CHARGER_RT9467
module CHARGER_RT9471
module CHARGER_SMB347

# Powercap
enable POWERCAP
enable IDLE_INJECT
case "$arch" in
    x86_64)
        module INTEL_RAPL
    ;;
esac

# Needed for installation ISO on some VMs like Parallels. This is
# already available built-in on x84. But other architectures now need
# it.
module BLK_DEV_SR

# Fast charging for apple devices
module APPLE_MFI_FASTCHARGE

enable IDLE_PAGE_TRACKING

# Tablet mode on Framework 12
if has ACPI; then
  module INPUT_SOC_BUTTON_ARRAY
fi

# MPTCP support
enable MPTCP
enable MPTCP_IPV6

# Can improve performance. i915 and v3d drm drivers recommend enabling it.
if has HAVE_ARCH_TRANSPARENT_HUGEPAGE; then
    enable TRANSPARENT_HUGEPAGE
fi
